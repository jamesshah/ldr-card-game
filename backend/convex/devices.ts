import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { userMutation } from "./lib/auth";
import { apnsConfigured } from "./lib/apnsConfig";

const apnsEnvironment = v.union(v.literal("sandbox"), v.literal("production"));

export const register = userMutation({
  args: { apnsToken: v.string(), environment: apnsEnvironment },
  returns: v.boolean(),
  handler: async (ctx, { apnsToken, environment }) => {
    const existing = await ctx.db
      .query("devices")
      .withIndex("by_token", (q) => q.eq("apnsToken", apnsToken))
      .unique();
    if (existing) {
      await ctx.db.patch("devices", existing._id, { userId: ctx.user._id, environment });
    } else {
      await ctx.db.insert("devices", { userId: ctx.user._id, apnsToken, environment });
    }
    return apnsConfigured();
  },
});

export const unregister = userMutation({
  args: { apnsToken: v.string() },
  returns: v.null(),
  handler: async (ctx, { apnsToken }) => {
    const existing = await ctx.db
      .query("devices")
      .withIndex("by_token", (q) => q.eq("apnsToken", apnsToken))
      .unique();
    if (existing && existing.userId === ctx.user._id) await ctx.db.delete("devices", existing._id);
    return null;
  },
});

export const forUser = internalQuery({
  args: { userId: v.id("users") },
  returns: v.array(v.object({ apnsToken: v.string(), environment: apnsEnvironment })),
  handler: async (ctx, { userId }) => {
    const devices = await ctx.db
      .query("devices")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .take(20);
    return devices.map((d) => ({ apnsToken: d.apnsToken, environment: d.environment }));
  },
});

export const removeTokens = internalMutation({
  args: { apnsTokens: v.array(v.string()) },
  returns: v.null(),
  handler: async (ctx, { apnsTokens }) => {
    for (const apnsToken of apnsTokens) {
      const existing = await ctx.db
        .query("devices")
        .withIndex("by_token", (q) => q.eq("apnsToken", apnsToken))
        .unique();
      if (existing) await ctx.db.delete("devices", existing._id);
    }
    return null;
  },
});
