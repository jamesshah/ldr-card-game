import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export const cardKind = v.union(v.literal("action"), v.literal("counter"));

export const playState = v.union(
  v.literal("pending"),
  v.literal("proofSubmitted"),
  v.literal("completed"),
  v.literal("refused"),
  v.literal("countered"),
);

export const proofType = v.union(
  v.literal("text"),
  v.literal("photo"),
  v.literal("audio"),
);

export default defineSchema({
  users: defineTable({
    name: v.string(),
    appleSub: v.optional(v.string()),
    isDevAccount: v.optional(v.boolean()),
    timeZone: v.string(),
    utcOffsetMinutes: v.number(),
    // Minutes after local midnight. Quiet hours may wrap past midnight (e.g. 1380 -> 420).
    quietStartMinutes: v.optional(v.number()),
    quietEndMinutes: v.optional(v.number()),
    coupleId: v.optional(v.id("couples")),
  }).index("by_appleSub", ["appleSub"]),

  sessions: defineTable({
    userId: v.id("users"),
    token: v.string(),
  })
    .index("by_token", ["token"])
    .index("by_user", ["userId"]),

  couples: defineTable({
    inviteCode: v.string(),
    playerA: v.id("users"),
    playerB: v.optional(v.id("users")),
    status: v.union(
      v.literal("waiting"),
      v.literal("active"),
      v.literal("ended"),
    ),
    timeframeDays: v.number(),
    startedAt: v.optional(v.number()),
    endsAt: v.optional(v.number()),
  }).index("by_inviteCode", ["inviteCode"]),

  cards: defineTable({
    slug: v.optional(v.string()),
    title: v.string(),
    body: v.string(),
    category: v.string(),
    kind: cardKind,
    coupleId: v.optional(v.id("couples")),
    createdBy: v.optional(v.id("users")),
  })
    .index("by_slug", ["slug"])
    .index("by_couple_and_creator", ["coupleId", "createdBy"]),

  hands: defineTable({
    coupleId: v.id("couples"),
    ownerId: v.id("users"),
    cardId: v.id("cards"),
    usedAt: v.optional(v.number()),
    stolenFromId: v.optional(v.id("users")),
    acquiredAt: v.number(),
  })
    .index("by_couple_and_owner", ["coupleId", "ownerId"]),

  plays: defineTable({
    coupleId: v.id("couples"),
    cardId: v.id("cards"),
    handId: v.id("hands"),
    fromId: v.id("users"),
    toId: v.id("users"),
    kind: cardKind,
    state: playState,
    stackedOnPlayId: v.optional(v.id("plays")),
    counteredPlayId: v.optional(v.id("plays")),
    counteredByPlayId: v.optional(v.id("plays")),
    delivered: v.boolean(),
    deliverAt: v.number(),
    playedAt: v.number(),
    respondedAt: v.optional(v.number()),
    proofType: v.optional(proofType),
    proofText: v.optional(v.string()),
    proofStorageId: v.optional(v.id("_storage")),
    proofRejectedNote: v.optional(v.string()),
    stolenHandId: v.optional(v.id("hands")),
  })
    // Kept alongside the compound index because the timeline needs _creationTime order.
    // eslint-disable-next-line @convex-dev/no-duplicate-indexes
    .index("by_couple", ["coupleId"])
    .index("by_couple_and_from_and_state", ["coupleId", "fromId", "state"]),

  devices: defineTable({
    userId: v.id("users"),
    apnsToken: v.string(),
    environment: v.union(v.literal("sandbox"), v.literal("production")),
  })
    .index("by_user", ["userId"])
    .index("by_token", ["apnsToken"]),
});
