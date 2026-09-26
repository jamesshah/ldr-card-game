import { ConvexError, v } from "convex/values";
import { requireCouple, userMutation, userQuery } from "./lib/auth";
import { MAX_CUSTOM_CARDS_PER_PLAYER } from "./lib/rules";
import { handCardView } from "./lib/validators";

export const myHand = userQuery({
  args: {},
  returns: v.object({
    cards: v.array(handCardView),
    usedCount: v.number(),
    partnerCardsLeft: v.number(),
    customCardsLeftToWrite: v.number(),
  }),
  handler: async (ctx) => {
    const me = ctx.user;
    const coupleId = me.coupleId;
    if (!coupleId) {
      return { cards: [], usedCount: 0, partnerCardsLeft: 0, customCardsLeftToWrite: 0 };
    }
    // Hands are bounded by the deck size (~60 cards plus a few custom ones).
    const hands = await ctx.db
      .query("hands")
      .withIndex("by_couple_and_owner", (q) => q.eq("coupleId", coupleId))
      .collect();
    const mine = hands.filter((h) => h.ownerId === me._id);
    const unused = mine.filter((h) => h.usedAt === undefined);

    const cards = await Promise.all(
      unused.map(async (h) => {
        const card = await ctx.db.get("cards", h.cardId);
        const stolenFrom = h.stolenFromId ? await ctx.db.get("users", h.stolenFromId) : null;
        return {
          handId: h._id,
          cardId: h.cardId,
          title: card?.title ?? "Unknown card",
          body: card?.body ?? "",
          category: card?.category ?? "",
          kind: card?.kind ?? "action",
          isCustom: card?.coupleId !== undefined,
          stolenFromName: stolenFrom?.name,
          acquiredAt: h.acquiredAt,
        };
      }),
    );
    cards.sort((a, b) => {
      // New custom cards are dealt to the front, newest first. The catalog cards keep
      // their existing action/category order, so creating one card never reshuffles the deck.
      if (a.isCustom || b.isCustom) {
        if (a.isCustom && b.isCustom) return b.acquiredAt - a.acquiredAt;
        return a.isCustom ? -1 : 1;
      }
      return a.kind === b.kind ? a.category.localeCompare(b.category) : a.kind === "action" ? -1 : 1;
    });

    const customWritten = await ctx.db
      .query("cards")
      .withIndex("by_couple_and_creator", (q) => q.eq("coupleId", coupleId).eq("createdBy", me._id))
      .collect();

    return {
      cards: cards.map((card) => ({
        handId: card.handId,
        cardId: card.cardId,
        title: card.title,
        body: card.body,
        category: card.category,
        kind: card.kind,
        isCustom: card.isCustom,
        stolenFromName: card.stolenFromName,
      })),
      usedCount: mine.length - unused.length,
      partnerCardsLeft: hands.filter((h) => h.ownerId !== me._id && h.usedAt === undefined).length,
      customCardsLeftToWrite: Math.max(0, MAX_CUSTOM_CARDS_PER_PLAYER - customWritten.length),
    };
  },
});

export const createCustom = userMutation({
  args: { title: v.string(), body: v.string() },
  returns: v.null(),
  handler: async (ctx, args) => {
    const { couple } = await requireCouple(ctx, ctx.user, { mustBeActive: false });
    if (couple.status === "ended") throw new ConvexError("This season has ended.");
    const title = args.title.trim();
    const body = args.body.trim();
    if (title.length < 3 || title.length > 60) {
      throw new ConvexError("Card titles need to be between 3 and 60 characters.");
    }
    if (body.length > 280) throw new ConvexError("Keep the card description under 280 characters.");

    const written = await ctx.db
      .query("cards")
      .withIndex("by_couple_and_creator", (q) => q.eq("coupleId", couple._id).eq("createdBy", ctx.user._id))
      .collect();
    if (written.length >= MAX_CUSTOM_CARDS_PER_PLAYER) {
      throw new ConvexError(`You can write up to ${MAX_CUSTOM_CARDS_PER_PLAYER} custom cards per season.`);
    }

    const cardId = await ctx.db.insert("cards", {
      title,
      body,
      category: "Custom",
      kind: "action",
      coupleId: couple._id,
      createdBy: ctx.user._id,
    });
    await ctx.db.insert("hands", {
      coupleId: couple._id,
      ownerId: ctx.user._id,
      cardId,
      acquiredAt: Date.now(),
    });
    return null;
  },
});
