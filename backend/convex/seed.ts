import { v } from "convex/values";
import { internalMutation } from "./_generated/server";
import { SEED_CARDS } from "./seedData";

/** Idempotent: inserts new catalog cards and updates existing ones by slug. Run with `npx convex run seed:run`. */
export const run = internalMutation({
  args: {},
  returns: v.object({ inserted: v.number(), updated: v.number() }),
  handler: async (ctx) => {
    let inserted = 0;
    let updated = 0;
    for (const card of SEED_CARDS) {
      const existing = await ctx.db
        .query("cards")
        .withIndex("by_slug", (q) => q.eq("slug", card.slug))
        .unique();
      if (existing) {
        await ctx.db.patch("cards", existing._id, {
          title: card.title,
          body: card.body,
          category: card.category,
          kind: card.kind,
        });
        updated++;
      } else {
        await ctx.db.insert("cards", card);
        inserted++;
      }
    }
    return { inserted, updated };
  },
});
