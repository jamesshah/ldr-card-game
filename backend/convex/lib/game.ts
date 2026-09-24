import { ConvexError } from "convex/values";
import { internal } from "../_generated/api";
import type { Doc, Id } from "../_generated/dataModel";
import type { MutationCtx, QueryCtx } from "../_generated/server";
import { requireActiveCouple, requireCouple } from "./auth";
import { deliveryTime } from "./rules";

type ProofInput = {
  proofType: "text" | "photo" | "audio";
  proofText?: string | null;
  proofStorageId?: Id<"_storage"> | null;
};

export async function notify(
  ctx: MutationCtx,
  userId: Id<"users">,
  title: string,
  body: string,
): Promise<void> {
  await ctx.scheduler.runAfter(0, internal.push.sendToUser, { userId, title, body });
}

function assertSeasonOpen(couple: Doc<"couples">, now: number): void {
  if (couple.endsAt !== undefined && now >= couple.endsAt) {
    throw new ConvexError("This season has ended. Check out your recap!");
  }
}

async function requireUnusedHand(
  ctx: QueryCtx,
  user: Doc<"users">,
  couple: Doc<"couples">,
  handId: Id<"hands">,
): Promise<{ hand: Doc<"hands">; card: Doc<"cards"> }> {
  const hand = await ctx.db.get("hands", handId);
  if (!hand || hand.coupleId !== couple._id || hand.ownerId !== user._id) {
    throw new ConvexError("That card isn't in your hand.");
  }
  if (hand.usedAt !== undefined) {
    throw new ConvexError("You've already used that card. Every card is single use.");
  }
  const card = await ctx.db.get("cards", hand.cardId);
  if (!card) throw new ConvexError("That card no longer exists.");
  return { hand, card };
}

async function requirePlayOnMe(
  ctx: QueryCtx,
  user: Doc<"users">,
  couple: Doc<"couples">,
  playId: Id<"plays">,
): Promise<Doc<"plays">> {
  const play = await ctx.db.get("plays", playId);
  if (!play || play.coupleId !== couple._id || play.toId !== user._id) {
    throw new ConvexError("That card wasn't played on you.");
  }
  if (!play.delivered) throw new ConvexError("That card hasn't been delivered yet.");
  if (play.state !== "pending") {
    throw new ConvexError("That card has already been answered.");
  }
  return play;
}

async function hasUnansweredPlay(
  ctx: QueryCtx,
  coupleId: Id<"couples">,
  fromId: Id<"users">,
): Promise<boolean> {
  const pending = await ctx.db
    .query("plays")
    .withIndex("by_couple_and_from_and_state", (q) =>
      q.eq("coupleId", coupleId).eq("fromId", fromId).eq("state", "pending"),
    )
    .first();
  return pending !== null;
}

export async function playCard(
  ctx: MutationCtx,
  user: Doc<"users">,
  args: { handId: Id<"hands">; stackedOnPlayId?: Id<"plays"> | null },
): Promise<Id<"plays">> {
  const { couple, partnerId } = await requireActiveCouple(ctx, user);
  const now = Date.now();
  assertSeasonOpen(couple, now);
  const { hand, card } = await requireUnusedHand(ctx, user, couple, args.handId);

  if (card.kind === "counter") {
    throw new ConvexError("Counter cards can only be used on a card played on you.");
  }

  let stackedOn: Doc<"plays"> | null = null;
  if (args.stackedOnPlayId) {
    stackedOn = await ctx.db.get("plays", args.stackedOnPlayId);
    if (!stackedOn || stackedOn.coupleId !== couple._id || stackedOn.toId !== user._id) {
      throw new ConvexError("You can only stack on a card your partner played on you.");
    }
    if (!stackedOn.delivered || (stackedOn.state !== "pending" && stackedOn.state !== "proofSubmitted")) {
      throw new ConvexError("You can only stack on a card that's still in play.");
    }
  }

  if (await hasUnansweredPlay(ctx, couple._id, user._id)) {
    throw new ConvexError(
      "Give your partner a chance to respond to your last card before playing another.",
    );
  }

  const partner = await ctx.db.get("users", partnerId);
  if (!partner) throw new ConvexError("Your partner could not be found.");
  const deliverAt = deliveryTime(now, partner);
  const delivered = deliverAt <= now;

  await ctx.db.patch("hands", hand._id, { usedAt: now });
  const playId = await ctx.db.insert("plays", {
    coupleId: couple._id,
    cardId: card._id,
    handId: hand._id,
    fromId: user._id,
    toId: partnerId,
    kind: "action",
    state: "pending",
    stackedOnPlayId: stackedOn?._id,
    delivered,
    deliverAt,
    playedAt: now,
  });

  if (delivered) {
    await notifyPlayDelivered(ctx, user.name, partnerId, card.title, stackedOn !== null);
  } else {
    await ctx.scheduler.runAt(deliverAt, internal.plays.deliver, { playId });
  }
  return playId;
}

async function notifyPlayDelivered(
  ctx: MutationCtx,
  fromName: string,
  toId: Id<"users">,
  cardTitle: string,
  stacked: boolean,
): Promise<void> {
  await notify(
    ctx,
    toId,
    stacked ? `${fromName} stacked a card on you` : `${fromName} played a card on you`,
    cardTitle,
  );
}

export async function deliverPlay(ctx: MutationCtx, playId: Id<"plays">): Promise<void> {
  const play = await ctx.db.get("plays", playId);
  if (!play || play.delivered) return;
  await ctx.db.patch("plays", playId, { delivered: true });
  const [from, card] = await Promise.all([
    ctx.db.get("users", play.fromId),
    ctx.db.get("cards", play.cardId),
  ]);
  await notifyPlayDelivered(
    ctx,
    from?.name ?? "Your partner",
    play.toId,
    card?.title ?? "A new card",
    play.stackedOnPlayId !== undefined,
  );
}

export async function counterPlay(
  ctx: MutationCtx,
  user: Doc<"users">,
  args: { handId: Id<"hands">; targetPlayId: Id<"plays"> },
): Promise<Id<"plays">> {
  const { couple, partnerId } = await requireActiveCouple(ctx, user);
  const now = Date.now();
  assertSeasonOpen(couple, now);
  const { hand, card } = await requireUnusedHand(ctx, user, couple, args.handId);
  if (card.kind !== "counter") {
    throw new ConvexError("Only counter cards can knock a card out of the game.");
  }
  const target = await requirePlayOnMe(ctx, user, couple, args.targetPlayId);

  await ctx.db.patch("hands", hand._id, { usedAt: now });
  const counterId = await ctx.db.insert("plays", {
    coupleId: couple._id,
    cardId: card._id,
    handId: hand._id,
    fromId: user._id,
    toId: partnerId,
    kind: "counter",
    state: "completed",
    counteredPlayId: target._id,
    delivered: true,
    deliverAt: now,
    playedAt: now,
    respondedAt: now,
  });
  await ctx.db.patch("plays", target._id, {
    state: "countered",
    counteredByPlayId: counterId,
    respondedAt: now,
  });

  const targetCard = await ctx.db.get("cards", target.cardId);
  await notify(
    ctx,
    partnerId,
    `${user.name} shut down your card`,
    `"${targetCard?.title ?? "Your card"}" was knocked out with ${card.title}.`,
  );
  return counterId;
}

export async function refusePlay(
  ctx: MutationCtx,
  user: Doc<"users">,
  args: { playId: Id<"plays"> },
  random: () => number = Math.random,
): Promise<void> {
  const { couple } = await requireCouple(ctx, user, { mustBeActive: false });
  const play = await requirePlayOnMe(ctx, user, couple, args.playId);
  const now = Date.now();

  const myHand = await ctx.db
    .query("hands")
    .withIndex("by_couple_and_owner", (q) =>
      q.eq("coupleId", couple._id).eq("ownerId", user._id),
    )
    .collect();
  const stealable = myHand.filter((h) => h.usedAt === undefined);
  const stolen =
    stealable.length > 0 ? stealable[Math.floor(random() * stealable.length)]! : null;

  if (stolen) {
    await ctx.db.patch("hands", stolen._id, {
      ownerId: play.fromId,
      stolenFromId: user._id,
      acquiredAt: now,
    });
  }
  await ctx.db.patch("plays", play._id, {
    state: "refused",
    respondedAt: now,
    stolenHandId: stolen?._id,
  });

  const [card, stolenCard] = await Promise.all([
    ctx.db.get("cards", play.cardId),
    stolen ? ctx.db.get("cards", stolen.cardId) : Promise.resolve(null),
  ]);
  await notify(
    ctx,
    play.fromId,
    `${user.name} refused "${card?.title ?? "your card"}"`,
    stolenCard
      ? `You stole "${stolenCard.title}" from their hand. Use it against them.`
      : "Their hand was empty, so there was nothing to steal.",
  );
}

export async function completeWithProof(
  ctx: MutationCtx,
  user: Doc<"users">,
  args: { playId: Id<"plays"> } & ProofInput,
): Promise<void> {
  const { couple } = await requireCouple(ctx, user, { mustBeActive: false });
  const play = await requirePlayOnMe(ctx, user, couple, args.playId);

  const text = args.proofText?.trim() || undefined;
  if (args.proofType === "text" && !text) {
    throw new ConvexError("Write a short note as proof.");
  }
  if (args.proofType !== "text" && !args.proofStorageId) {
    throw new ConvexError(`Attach a ${args.proofType === "photo" ? "photo" : "voice note"} as proof.`);
  }
  if (text && text.length > 1000) throw new ConvexError("Keep your note under 1000 characters.");

  await ctx.db.patch("plays", play._id, {
    state: "proofSubmitted",
    proofType: args.proofType,
    proofText: text,
    proofStorageId: args.proofStorageId ?? undefined,
    proofRejectedNote: undefined,
    respondedAt: Date.now(),
  });
  const card = await ctx.db.get("cards", play.cardId);
  await notify(ctx, play.fromId, `${user.name} sent proof`, `"${card?.title ?? "Your card"}" is ready for your review.`);
}

async function requireProofToReview(
  ctx: QueryCtx,
  user: Doc<"users">,
  playId: Id<"plays">,
): Promise<Doc<"plays">> {
  const { couple } = await requireCouple(ctx, user, { mustBeActive: false });
  const play = await ctx.db.get("plays", playId);
  if (!play || play.coupleId !== couple._id || play.fromId !== user._id) {
    throw new ConvexError("Only the person who played this card can review the proof.");
  }
  if (play.state !== "proofSubmitted") throw new ConvexError("There's no proof waiting on this card.");
  return play;
}

export async function acceptProof(
  ctx: MutationCtx,
  user: Doc<"users">,
  args: { playId: Id<"plays"> },
): Promise<void> {
  const play = await requireProofToReview(ctx, user, args.playId);
  await ctx.db.patch("plays", play._id, { state: "completed" });
  const card = await ctx.db.get("cards", play.cardId);
  await notify(ctx, play.toId, `${user.name} accepted your proof`, `"${card?.title ?? "Card"}" is complete.`);
}

export async function rejectProof(
  ctx: MutationCtx,
  user: Doc<"users">,
  args: { playId: Id<"plays">; note?: string | null },
): Promise<void> {
  const play = await requireProofToReview(ctx, user, args.playId);
  const note = args.note?.trim() || "Not quite. Try again!";
  if (play.proofStorageId) await ctx.storage.delete(play.proofStorageId);
  await ctx.db.patch("plays", play._id, {
    state: "pending",
    proofType: undefined,
    proofText: undefined,
    proofStorageId: undefined,
    proofRejectedNote: note.slice(0, 280),
  });
  const card = await ctx.db.get("cards", play.cardId);
  await notify(ctx, play.toId, `${user.name} wants another try`, `"${card?.title ?? "Card"}": ${note}`);
}
