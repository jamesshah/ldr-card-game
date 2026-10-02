import type { Doc, Id } from "../_generated/dataModel";
import type { MutationCtx } from "../_generated/server";

/** Cancel a scheduled job; ignore if it already ran or was canceled. */
export async function cancelJob(
  ctx: MutationCtx,
  jobId: Id<"_scheduled_functions"> | undefined,
): Promise<void> {
  if (!jobId) return;
  try {
    await ctx.scheduler.cancel(jobId);
  } catch {
    // Already completed or canceled.
  }
}

/** Cancel quiet-hours deliver timers still pending for this couple. */
export async function cancelPendingDeliverJobs(
  ctx: MutationCtx,
  coupleId: Id<"couples">,
): Promise<void> {
  const plays = await ctx.db
    .query("plays")
    .withIndex("by_couple", (q) => q.eq("coupleId", coupleId))
    .collect();
  for (const play of plays) {
    if (play.delivered || !play.deliverJobId) continue;
    await cancelJob(ctx, play.deliverJobId);
    await ctx.db.patch("plays", play._id, { deliverJobId: undefined });
  }
}

/**
 * Cancel the couple's endSeason timer and any quiet-hours deliver jobs still pending.
 * Call from user-driven exits (unpair, start new season) — not from endSeason itself.
 */
export async function cancelCoupleSeasonJobs(
  ctx: MutationCtx,
  couple: Doc<"couples">,
): Promise<void> {
  await cancelJob(ctx, couple.endSeasonJobId);
  if (couple.endSeasonJobId) {
    await ctx.db.patch("couples", couple._id, { endSeasonJobId: undefined });
  }
  await cancelPendingDeliverJobs(ctx, couple._id);
}
