import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { internalMutation, type QueryCtx } from "./_generated/server";
import { requireCouple, userMutation, userQuery } from "./lib/auth";
import * as game from "./lib/game";
import { nullable, playView } from "./lib/validators";
import { proofType } from "./schema";

const TIMELINE_LIMIT = 300;

export const playCard = userMutation({
  args: { handId: v.id("hands"), stackedOnPlayId: nullable(v.id("plays")) },
  returns: v.null(),
  handler: async (ctx, args) => {
    await game.playCard(ctx, ctx.user, args);
    return null;
  },
});

export const counter = userMutation({
  args: { handId: v.id("hands"), targetPlayId: v.id("plays") },
  returns: v.null(),
  handler: async (ctx, args) => {
    await game.counterPlay(ctx, ctx.user, args);
    return null;
  },
});

export const refuse = userMutation({
  args: { playId: v.id("plays") },
  returns: v.null(),
  handler: async (ctx, args) => {
    await game.refusePlay(ctx, ctx.user, args);
    return null;
  },
});

export const completeWithProof = userMutation({
  args: {
    playId: v.id("plays"),
    proofType,
    proofText: nullable(v.string()),
    proofStorageId: nullable(v.id("_storage")),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    await game.completeWithProof(ctx, ctx.user, args);
    return null;
  },
});

export const acceptProof = userMutation({
  args: { playId: v.id("plays") },
  returns: v.null(),
  handler: async (ctx, args) => {
    await game.acceptProof(ctx, ctx.user, args);
    return null;
  },
});

export const rejectProof = userMutation({
  args: { playId: v.id("plays"), note: nullable(v.string()) },
  returns: v.null(),
  handler: async (ctx, args) => {
    await game.rejectProof(ctx, ctx.user, args);
    return null;
  },
});

export const generateUploadUrl = userMutation({
  args: {},
  returns: v.string(),
  handler: async (ctx) => {
    await requireCouple(ctx, ctx.user, { mustBeActive: false });
    return await ctx.storage.generateUploadUrl();
  },
});

export const deliver = internalMutation({
  args: { playId: v.id("plays") },
  returns: v.null(),
  handler: async (ctx, { playId }) => {
    await game.deliverPlay(ctx, playId);
    return null;
  },
});

async function toPlayViews(ctx: QueryCtx, plays: Doc<"plays">[]) {
  const names = new Map<Id<"users">, string>();
  const nameOf = async (id: Id<"users">) => {
    if (!names.has(id)) names.set(id, (await ctx.db.get("users", id))?.name ?? "Someone");
    return names.get(id)!;
  };
  const titleOfPlay = async (id: Id<"plays"> | undefined) => {
    if (!id) return undefined;
    const p = await ctx.db.get("plays", id);
    return p ? (await ctx.db.get("cards", p.cardId))?.title : undefined;
  };

  return await Promise.all(
    plays.map(async (p) => {
      const card = await ctx.db.get("cards", p.cardId);
      const stolenHand = p.stolenHandId ? await ctx.db.get("hands", p.stolenHandId) : null;
      const stolenCard = stolenHand ? await ctx.db.get("cards", stolenHand.cardId) : null;
      return {
        _id: p._id,
        cardId: p.cardId,
        title: card?.title ?? "Unknown card",
        body: card?.body ?? "",
        category: card?.category ?? "",
        kind: p.kind,
        fromId: p.fromId,
        toId: p.toId,
        fromName: await nameOf(p.fromId),
        toName: await nameOf(p.toId),
        state: p.state,
        stackedOnPlayId: p.stackedOnPlayId,
        stackedOnTitle: await titleOfPlay(p.stackedOnPlayId),
        counteredPlayId: p.counteredPlayId,
        counteredTitle: await titleOfPlay(p.counteredPlayId),
        delivered: p.delivered,
        deliverAt: p.deliverAt,
        playedAt: p.playedAt,
        respondedAt: p.respondedAt,
        proofType: p.proofType,
        proofText: p.proofText,
        proofUrl: p.proofStorageId ? ((await ctx.storage.getUrl(p.proofStorageId)) ?? undefined) : undefined,
        proofRejectedNote: p.proofRejectedNote,
        stolenCardTitle: stolenCard?.title,
      };
    }),
  );
}

async function couplePlays(ctx: QueryCtx, coupleId: Id<"couples">) {
  // A season holds at most ~70 plays (60-card deck plus custom cards), so this stays bounded.
  return await ctx.db
    .query("plays")
    .withIndex("by_couple", (q) => q.eq("coupleId", coupleId))
    .order("desc")
    .take(TIMELINE_LIMIT);
}

export const inbox = userQuery({
  args: {},
  returns: v.object({
    incoming: v.array(playView),
    toReview: v.array(playView),
    waitingOnPartner: v.array(playView),
  }),
  handler: async (ctx) => {
    const me = ctx.user;
    if (!me.coupleId) return { incoming: [], toReview: [], waitingOnPartner: [] };
    const plays = await couplePlays(ctx, me.coupleId);
    const open = plays.filter((p) => p.state === "pending" || p.state === "proofSubmitted");
    const incoming = open.filter((p) => p.toId === me._id && p.delivered);
    const toReview = open.filter((p) => p.fromId === me._id && p.state === "proofSubmitted");
    const waitingOnPartner = open.filter((p) => p.fromId === me._id && p.state === "pending");
    return {
      incoming: await toPlayViews(ctx, incoming),
      toReview: await toPlayViews(ctx, toReview),
      waitingOnPartner: await toPlayViews(ctx, waitingOnPartner),
    };
  },
});

export const timeline = userQuery({
  args: {},
  returns: v.array(playView),
  handler: async (ctx) => {
    const me = ctx.user;
    if (!me.coupleId) return [];
    const plays = await couplePlays(ctx, me.coupleId);
    // Cards held back by quiet hours stay a surprise until they're delivered.
    const visible = plays.filter((p) => p.delivered || p.fromId === me._id);
    return await toPlayViews(ctx, visible);
  },
});
