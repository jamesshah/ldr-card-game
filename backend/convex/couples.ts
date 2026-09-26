import { ConvexError, v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import { internalMutation, type MutationCtx, type QueryCtx } from "./_generated/server";
import { userMutation, userQuery } from "./lib/auth";
import { dealDeck, makeInviteCode, normalizeInviteCode, TIMEFRAME_OPTIONS_DAYS } from "./lib/rules";
import { playerView, recapPlayer } from "./lib/validators";

const DAY_MS = 24 * 60 * 60 * 1000;

function toPlayerView(u: Doc<"users">) {
  return {
    _id: u._id,
    name: u.name,
    timeZone: u.timeZone,
    utcOffsetMinutes: u.utcOffsetMinutes,
    quietStartMinutes: u.quietStartMinutes,
    quietEndMinutes: u.quietEndMinutes,
  };
}

async function uniqueInviteCode(ctx: QueryCtx): Promise<string> {
  for (let attempt = 0; attempt < 10; attempt++) {
    const code = makeInviteCode();
    const clash = await ctx.db
      .query("couples")
      .withIndex("by_inviteCode", (q) => q.eq("inviteCode", code))
      .first();
    if (!clash) return code;
  }
  throw new ConvexError("Couldn't generate an invite code. Please try again.");
}

async function dealHands(ctx: MutationCtx, couple: Doc<"couples">, playerB: Id<"users">, now: number) {
  const catalog = await ctx.db
    .query("cards")
    .withIndex("by_couple_and_creator", (q) => q.eq("coupleId", undefined))
    .collect();
  if (catalog.length === 0) {
    throw new ConvexError("The card deck hasn't been set up yet. Run the seed first.");
  }
  const [handA, handB] = dealDeck(catalog);
  const give = async (cards: Doc<"cards">[], ownerId: Id<"users">) => {
    for (const card of cards) {
      await ctx.db.insert("hands", { coupleId: couple._id, ownerId, cardId: card._id, acquiredAt: now });
    }
  };
  await give(handA, couple.playerA);
  await give(handB, playerB);
}

export const create = userMutation({
  args: { timeframeDays: v.number() },
  returns: v.null(),
  handler: async (ctx, { timeframeDays }) => {
    if (ctx.user.coupleId) throw new ConvexError("You're already in a couple.");
    if (!(TIMEFRAME_OPTIONS_DAYS as readonly number[]).includes(timeframeDays)) {
      throw new ConvexError("Pick a timeframe of a week, a month, 3 months, or 6 months.");
    }
    const coupleId = await ctx.db.insert("couples", {
      inviteCode: await uniqueInviteCode(ctx),
      playerA: ctx.user._id,
      status: "waiting",
      timeframeDays,
    });
    await ctx.db.patch("users", ctx.user._id, { coupleId });
    return null;
  },
});

export const join = userMutation({
  args: { inviteCode: v.string() },
  returns: v.null(),
  handler: async (ctx, { inviteCode }) => {
    if (ctx.user.coupleId) throw new ConvexError("You're already in a couple.");
    const couple = await ctx.db
      .query("couples")
      .withIndex("by_inviteCode", (q) => q.eq("inviteCode", normalizeInviteCode(inviteCode)))
      .first();
    if (!couple || couple.status !== "waiting") {
      throw new ConvexError("That invite code doesn't match an open invite.");
    }
    if (couple.playerA === ctx.user._id) throw new ConvexError("You can't join your own invite.");

    const now = Date.now();
    const endsAt = now + couple.timeframeDays * DAY_MS;
    await ctx.db.patch("couples", couple._id, {
      playerB: ctx.user._id,
      status: "active",
      startedAt: now,
      endsAt,
    });
    await ctx.db.patch("users", ctx.user._id, { coupleId: couple._id });
    await dealHands(ctx, couple, ctx.user._id, now);
    await ctx.scheduler.runAt(endsAt, internal.couples.endSeason, { coupleId: couple._id });
    await ctx.scheduler.runAfter(0, internal.push.sendToUser, {
      userId: couple.playerA,
      title: `${ctx.user.name} joined!`,
      body: "Your season has started. Your hand is ready.",
    });
    return null;
  },
});

export const cancelInvite = userMutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const coupleId = ctx.user.coupleId;
    if (!coupleId) return null;
    const couple = await ctx.db.get("couples", coupleId);
    if (couple && couple.status !== "waiting") {
      throw new ConvexError("You can only cancel an invite your partner hasn't accepted.");
    }
    const customCards = await ctx.db
      .query("cards")
      .withIndex("by_couple_and_creator", (q) => q.eq("coupleId", coupleId))
      .collect();
    for (const card of customCards) await ctx.db.delete("cards", card._id);
    const hands = await ctx.db
      .query("hands")
      .withIndex("by_couple_and_owner", (q) => q.eq("coupleId", coupleId))
      .collect();
    for (const hand of hands) await ctx.db.delete("hands", hand._id);
    if (couple) await ctx.db.delete("couples", couple._id);
    await ctx.db.patch("users", ctx.user._id, { coupleId: undefined });
    return null;
  },
});

export const endSeason = internalMutation({
  args: { coupleId: v.id("couples") },
  returns: v.null(),
  handler: async (ctx, { coupleId }) => {
    const couple = await ctx.db.get("couples", coupleId);
    if (!couple || couple.status !== "active") return null;
    await ctx.db.patch("couples", coupleId, { status: "ended" });
    for (const userId of [couple.playerA, couple.playerB]) {
      if (!userId) continue;
      await ctx.scheduler.runAfter(0, internal.push.sendToUser, {
        userId,
        title: "Your season is over",
        body: "Open the app to see your recap.",
      });
    }
    return null;
  },
});

export const current = userQuery({
  args: {},
  returns: v.union(
    v.null(),
    v.object({
      _id: v.id("couples"),
      status: v.union(v.literal("waiting"), v.literal("active"), v.literal("ended")),
      inviteCode: v.string(),
      timeframeDays: v.number(),
      startedAt: v.optional(v.number()),
      endsAt: v.optional(v.number()),
      me: playerView,
      partner: v.optional(playerView),
    }),
  ),
  handler: async (ctx) => {
    if (!ctx.user.coupleId) return null;
    const couple = await ctx.db.get("couples", ctx.user.coupleId);
    if (!couple) return null;
    const partnerId = couple.playerA === ctx.user._id ? couple.playerB : couple.playerA;
    const partner = partnerId ? await ctx.db.get("users", partnerId) : null;
    return {
      _id: couple._id,
      status: couple.status,
      inviteCode: couple.inviteCode,
      timeframeDays: couple.timeframeDays,
      startedAt: couple.startedAt,
      endsAt: couple.endsAt,
      me: toPlayerView(ctx.user),
      partner: partner ? toPlayerView(partner) : undefined,
    };
  },
});

export const recap = userQuery({
  args: {},
  returns: v.union(
    v.null(),
    v.object({
      status: v.union(v.literal("waiting"), v.literal("active"), v.literal("ended")),
      startedAt: v.optional(v.number()),
      endsAt: v.optional(v.number()),
      players: v.array(recapPlayer),
    }),
  ),
  handler: async (ctx) => {
    if (!ctx.user.coupleId) return null;
    const couple = await ctx.db.get("couples", ctx.user.coupleId);
    if (!couple || !couple.playerB) return null;
    const plays = await ctx.db
      .query("plays")
      .withIndex("by_couple", (q) => q.eq("coupleId", couple._id))
      .collect();
    const hands = await ctx.db
      .query("hands")
      .withIndex("by_couple_and_owner", (q) => q.eq("coupleId", couple._id))
      .collect();

    const partnerId = couple.playerA === ctx.user._id ? couple.playerB : couple.playerA;
    const players = [];
    // UI lays this array out left-to-right. Partner is always left, signed-in user right.
    for (const userId of [partnerId, ctx.user._id]) {
      const user = await ctx.db.get("users", userId);
      const actions = plays.filter((p) => p.kind === "action");
      players.push({
        userId,
        name: user?.name ?? "Player",
        played: actions.filter((p) => p.fromId === userId).length,
        completedByPartner: actions.filter((p) => p.fromId === userId && p.state === "completed").length,
        refusedByPartner: actions.filter((p) => p.fromId === userId && p.state === "refused").length,
        refused: actions.filter((p) => p.toId === userId && p.state === "refused").length,
        countersUsed: plays.filter((p) => p.kind === "counter" && p.fromId === userId).length,
        cardsStolen: actions.filter((p) => p.fromId === userId && p.stolenHandId !== undefined).length,
        cardsLeft: hands.filter((h) => h.ownerId === userId && h.usedAt === undefined).length,
      });
    }
    return { status: couple.status, startedAt: couple.startedAt, endsAt: couple.endsAt, players };
  },
});
