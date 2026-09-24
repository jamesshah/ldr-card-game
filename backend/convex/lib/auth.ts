import { customMutation, customQuery } from "convex-helpers/server/customFunctions";
import { ConvexError, v } from "convex/values";
import type { Doc, Id } from "../_generated/dataModel";
import { mutation, query, type QueryCtx } from "../_generated/server";

export async function userFromSession(
  ctx: QueryCtx,
  sessionToken: string,
): Promise<Doc<"users"> | null> {
  const session = await ctx.db
    .query("sessions")
    .withIndex("by_token", (q) => q.eq("token", sessionToken))
    .unique();
  if (!session) return null;
  return await ctx.db.get("users", session.userId);
}

async function requireUser(ctx: QueryCtx, sessionToken: string): Promise<Doc<"users">> {
  const user = await userFromSession(ctx, sessionToken);
  if (!user) throw new ConvexError("Your session has expired. Please sign in again.");
  return user;
}

/** Query that requires a valid session; the signed-in user is available as `ctx.user`. */
export const userQuery = customQuery(query, {
  args: { sessionToken: v.string() },
  input: async (ctx, { sessionToken }) => {
    const user = await requireUser(ctx, sessionToken);
    return { ctx: { user }, args: {} };
  },
});

/** Mutation that requires a valid session; the signed-in user is available as `ctx.user`. */
export const userMutation = customMutation(mutation, {
  args: { sessionToken: v.string() },
  input: async (ctx, { sessionToken }) => {
    const user = await requireUser(ctx, sessionToken);
    return { ctx: { user }, args: {} };
  },
});

export type CoupleContext = {
  couple: Doc<"couples">;
  partnerId: Id<"users"> | undefined;
};

export async function requireCouple(
  ctx: QueryCtx,
  user: Doc<"users">,
  opts: { mustBeActive: boolean },
): Promise<CoupleContext> {
  if (!user.coupleId) throw new ConvexError("You're not paired with a partner yet.");
  const couple = await ctx.db.get("couples", user.coupleId);
  if (!couple) throw new ConvexError("Your couple could not be found.");
  if (opts.mustBeActive && couple.status !== "active") {
    throw new ConvexError(
      couple.status === "waiting"
        ? "Your partner hasn't joined yet. Share your invite code."
        : "This season has ended.",
    );
  }
  const partnerId = couple.playerA === user._id ? couple.playerB : couple.playerA;
  return { couple, partnerId };
}

export async function requireActiveCouple(
  ctx: QueryCtx,
  user: Doc<"users">,
): Promise<{ couple: Doc<"couples">; partnerId: Id<"users"> }> {
  const { couple, partnerId } = await requireCouple(ctx, user, { mustBeActive: true });
  if (!partnerId) throw new ConvexError("Your partner hasn't joined yet.");
  return { couple, partnerId };
}
