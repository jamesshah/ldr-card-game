import { v, type Validator } from "convex/values";
import { cardKind, playState, proofType } from "../schema";

/** Optional arg that also accepts an explicit null, since Swift clients often send null for nil. */
export function nullable<T extends Validator<unknown, "required", string>>(validator: T) {
  return v.optional(v.union(validator, v.null()));
}

export const playerView = v.object({
  _id: v.id("users"),
  name: v.string(),
  timeZone: v.string(),
  utcOffsetMinutes: v.number(),
  quietStartMinutes: v.optional(v.number()),
  quietEndMinutes: v.optional(v.number()),
});

export const handCardView = v.object({
  handId: v.id("hands"),
  cardId: v.id("cards"),
  title: v.string(),
  body: v.string(),
  category: v.string(),
  kind: cardKind,
  isCustom: v.boolean(),
  stolenFromName: v.optional(v.string()),
});

export const playView = v.object({
  _id: v.id("plays"),
  cardId: v.id("cards"),
  title: v.string(),
  body: v.string(),
  category: v.string(),
  kind: cardKind,
  fromId: v.id("users"),
  toId: v.id("users"),
  fromName: v.string(),
  toName: v.string(),
  state: playState,
  stackedOnPlayId: v.optional(v.id("plays")),
  stackedOnTitle: v.optional(v.string()),
  counteredPlayId: v.optional(v.id("plays")),
  counteredTitle: v.optional(v.string()),
  delivered: v.boolean(),
  deliverAt: v.number(),
  playedAt: v.number(),
  respondedAt: v.optional(v.number()),
  proofType: v.optional(proofType),
  proofText: v.optional(v.string()),
  proofUrl: v.optional(v.string()),
  proofRejectedNote: v.optional(v.string()),
  stolenCardTitle: v.optional(v.string()),
});

export const recapPlayer = v.object({
  userId: v.id("users"),
  name: v.string(),
  played: v.number(),
  completedByPartner: v.number(),
  refusedByPartner: v.number(),
  refused: v.number(),
  countersUsed: v.number(),
  cardsStolen: v.number(),
  cardsLeft: v.number(),
});
