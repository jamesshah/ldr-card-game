/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as apns from "../apns.js";
import type * as auth from "../auth.js";
import type * as cards from "../cards.js";
import type * as couples from "../couples.js";
import type * as devices from "../devices.js";
import type * as lib_auth from "../lib/auth.js";
import type * as lib_game from "../lib/game.js";
import type * as lib_rules from "../lib/rules.js";
import type * as lib_validators from "../lib/validators.js";
import type * as plays from "../plays.js";
import type * as push from "../push.js";
import type * as seed from "../seed.js";
import type * as seedData from "../seedData.js";
import type * as users from "../users.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  apns: typeof apns;
  auth: typeof auth;
  cards: typeof cards;
  couples: typeof couples;
  devices: typeof devices;
  "lib/auth": typeof lib_auth;
  "lib/game": typeof lib_game;
  "lib/rules": typeof lib_rules;
  "lib/validators": typeof lib_validators;
  plays: typeof plays;
  push: typeof push;
  seed: typeof seed;
  seedData: typeof seedData;
  users: typeof users;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
