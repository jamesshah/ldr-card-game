export const MINUTES_PER_DAY = 24 * 60;
const MS_PER_MINUTE = 60_000;

export const MAX_CUSTOM_CARDS_PER_PLAYER = 5;
export const TIMEFRAME_OPTIONS_DAYS = [7, 30, 90, 180] as const;

export type QuietHours = {
  utcOffsetMinutes: number;
  quietStartMinutes?: number;
  quietEndMinutes?: number;
};

function localMinuteOfDay(nowMs: number, utcOffsetMinutes: number): number {
  const localMinutes = Math.floor(nowMs / MS_PER_MINUTE) + utcOffsetMinutes;
  return ((localMinutes % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY;
}

export function isInQuietHours(nowMs: number, q: QuietHours): boolean {
  const { quietStartMinutes: start, quietEndMinutes: end } = q;
  if (start === undefined || end === undefined || start === end) return false;
  const m = localMinuteOfDay(nowMs, q.utcOffsetMinutes);
  return start < end ? m >= start && m < end : m >= start || m < end;
}

/**
 * When a card played at `nowMs` should reach the target: immediately, or the
 * moment the target's quiet hours end.
 */
export function deliveryTime(nowMs: number, q: QuietHours): number {
  if (!isInQuietHours(nowMs, q)) return nowMs;
  const end = q.quietEndMinutes!;
  const m = localMinuteOfDay(nowMs, q.utcOffsetMinutes);
  const minutesUntilEnd = (end - m + MINUTES_PER_DAY) % MINUTES_PER_DAY;
  const startOfMinute = Math.floor(nowMs / MS_PER_MINUTE) * MS_PER_MINUTE;
  return startOfMinute + minutesUntilEnd * MS_PER_MINUTE;
}

export function shuffle<T>(items: readonly T[], random: () => number = Math.random): T[] {
  const out = [...items];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [out[i], out[j]] = [out[j]!, out[i]!];
  }
  return out;
}

/**
 * Splits the deck so each player gets a unique half, with counter cards
 * divided as evenly as possible.
 */
export function dealDeck<T extends { kind: "action" | "counter" }>(
  deck: readonly T[],
  random: () => number = Math.random,
): [T[], T[]] {
  const a: T[] = [];
  const b: T[] = [];
  const counters = shuffle(deck.filter((c) => c.kind === "counter"), random);
  const actions = shuffle(deck.filter((c) => c.kind === "action"), random);
  counters.forEach((c, i) => (i % 2 === 0 ? a : b).push(c));
  for (const c of actions) (a.length <= b.length ? a : b).push(c);
  return [a, b];
}

const INVITE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";

export function makeInviteCode(random: () => number = Math.random): string {
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += INVITE_ALPHABET[Math.floor(random() * INVITE_ALPHABET.length)];
  }
  return code;
}

export function makeSessionToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

export function normalizeInviteCode(code: string): string {
  return code.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}
