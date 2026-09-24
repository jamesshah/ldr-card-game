import { ConvexError, v } from "convex/values";
import { query } from "./_generated/server";
import { userFromSession, userMutation } from "./lib/auth";
import { MINUTES_PER_DAY } from "./lib/rules";
import { nullable } from "./lib/validators";

/** Returns null for an unknown or expired session so the app can drop a stale token. */
export const me = query({
  args: { sessionToken: v.string() },
  returns: v.union(
    v.null(),
    v.object({
      _id: v.id("users"),
      name: v.string(),
      timeZone: v.string(),
      utcOffsetMinutes: v.number(),
      quietStartMinutes: v.optional(v.number()),
      quietEndMinutes: v.optional(v.number()),
      coupleId: v.optional(v.id("couples")),
      isDevAccount: v.boolean(),
    }),
  ),
  handler: async (ctx, { sessionToken }) => {
    const user = await userFromSession(ctx, sessionToken);
    if (!user) return null;
    return {
      _id: user._id,
      name: user.name,
      timeZone: user.timeZone,
      utcOffsetMinutes: user.utcOffsetMinutes,
      quietStartMinutes: user.quietStartMinutes,
      quietEndMinutes: user.quietEndMinutes,
      coupleId: user.coupleId,
      isDevAccount: user.isDevAccount ?? false,
    };
  },
});

export const updateProfile = userMutation({
  args: { name: nullable(v.string()), timeZone: v.string(), utcOffsetMinutes: v.number() },
  returns: v.null(),
  handler: async (ctx, args) => {
    const name = args.name?.trim();
    if (name !== undefined && (name.length === 0 || name.length > 40)) {
      throw new ConvexError("Names need to be between 1 and 40 characters.");
    }
    await ctx.db.patch("users", ctx.user._id, {
      timeZone: args.timeZone,
      utcOffsetMinutes: args.utcOffsetMinutes,
      ...(name ? { name } : {}),
    });
    return null;
  },
});

/** Pass null for both to turn quiet hours off. */
export const setQuietHours = userMutation({
  args: { startMinutes: v.union(v.number(), v.null()), endMinutes: v.union(v.number(), v.null()) },
  returns: v.null(),
  handler: async (ctx, { startMinutes, endMinutes }) => {
    if (startMinutes === null || endMinutes === null) {
      await ctx.db.patch("users", ctx.user._id, {
        quietStartMinutes: undefined,
        quietEndMinutes: undefined,
      });
      return null;
    }
    const valid = (m: number) => Number.isInteger(m) && m >= 0 && m < MINUTES_PER_DAY;
    if (!valid(startMinutes) || !valid(endMinutes)) {
      throw new ConvexError("Quiet hours must be times within the day.");
    }
    await ctx.db.patch("users", ctx.user._id, {
      quietStartMinutes: startMinutes,
      quietEndMinutes: endMinutes,
    });
    return null;
  },
});
