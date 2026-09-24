# LDR Cards

A card game for long-distance couples. Each partner holds their own hand of cards and plays them on the other whenever they like: "Video call me right now", "Send a 30s voice note", "Order me a surprise delivery". The target completes the card and sends proof (a photo, voice note, or text), shuts it down with a counter card, or refuses it and lets their partner steal a card from their hand. A season runs for a week, a month, 3 months, or 6 months, then both players get a recap.

- **iOS app**: native SwiftUI (iOS 17+), using [ConvexMobile](https://github.com/get-convex/convex-swift) for realtime queries and mutations.
- **Backend**: [Convex](https://convex.dev). All game rules run in Convex mutations, so neither client can cheat.

## Rules

- Joining a couple deals the 60-card deck: each player gets a unique 30 cards, including 3 counter cards.
- Every card is single use.
- You can't play another card until your partner responds to your last one (completes, sends proof, counters, or refuses).
- Cards stack: you can play a card on top of one your partner played on you. Both stay in play, and neither cancels the other.
- **Counter** cards knock a card played on you out of the game.
- **Refusing** a card lets the sender steal a random card from your hand and use it against you.
- **Proof**: the target attaches a photo, voice note, or note. The sender accepts it or sends it back for another try.
- **Quiet hours**: a card played during your quiet hours is held and delivered when they end. Both players' local times are shown in the app.
- **Custom cards**: each player can write up to 5 of their own per season.

## Repo layout

```
backend/            Convex backend
  convex/
    schema.ts       users, sessions, couples, cards, hands, plays, devices
    lib/game.ts     game rules (play, stack, counter, refuse, proof)
    lib/rules.ts    pure helpers (quiet hours, dealing, invite codes)
    plays.ts        public play mutations + inbox/timeline queries
    couples.ts      create/join/cancel, season end, recap
    cards.ts        hand query, custom cards
    auth.ts         dev sign-in and Sign in with Apple
    push.ts         push dispatch (no-op until APNs is configured)
    apns.ts         APNs HTTP/2 sender ("use node")
    seedData.ts     the original 60-card LDR deck
    game.test.ts    rule tests (convex-test + vitest)
ios/LDRCards/       SwiftUI app
  project.yml       XcodeGen project spec
  Config/App.xcconfig   CONVEX_URL build setting
  LDRCards/         app sources
  LDRCardsTests/    unit tests
```

## Backend

Requires Node 20+.

```bash
cd backend
npm install
npm test            # rule tests
npm run lint
npx convex dev      # local/dev deployment; watches and pushes functions
npx convex run seed:run   # load the deck (safe to re-run)
```

Use `npx convex dev` for development. `npx convex deploy` is for production only.

### Deploying to the shared deployment

The app points at `https://loyal-lapwing-231.convex.cloud` by default. With a deploy key for that deployment (Convex dashboard, then Settings, then Deploy keys):

```bash
cd backend
export CONVEX_DEPLOY_KEY=...        # production deploy key for loyal-lapwing-231
npx convex deploy
npx convex run seed:run
```

### Environment variables

Set these in the Convex dashboard (Settings, then Environment Variables) or with `npx convex env set NAME value`.

| Variable | Purpose |
| --- | --- |
| `APPLE_BUNDLE_ID` | Audience for Sign in with Apple tokens. Defaults to `com.jamesshah.ldrcards`. |
| `DEV_SIGN_IN` | Set to `disabled` to turn off the name-only test sign-in. |
| `APNS_KEY_ID` | Key ID of your APNs auth key (.p8). |
| `APNS_TEAM_ID` | Your Apple Developer team ID. |
| `APNS_PRIVATE_KEY` | Contents of the .p8 file. Literal `\n` sequences are accepted. |
| `APNS_TOPIC` | The app's bundle ID, e.g. `com.jamesshah.ldrcards`. |

Without the `APNS_*` variables, pushes are skipped and the app falls back to realtime updates plus local notifications while it's running.

## iOS app (Mac setup)

Requires Xcode 15 or later with an iOS 17+ Simulator runtime, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd ios/LDRCards
xcodegen generate
open LDRCards.xcodeproj
```

Run the tests from the command line:

```bash
cd ios/LDRCards
xcodegen generate
xcodebuild test -project LDRCards.xcodeproj -scheme LDRCards \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Swift Package Manager fetches ConvexMobile on first build.

### Pointing at a different backend

`CONVEX_URL` lives in `ios/LDRCards/Config/App.xcconfig`. To override it without touching the repo, create `ios/LDRCards/Config/Local.xcconfig` (gitignored):

```
CONVEX_URL = http:/$()/127.0.0.1:3210
```

The `$()` keeps xcconfig from treating `//` as a comment. The Simulator can reach a local `npx convex dev` backend at `127.0.0.1`.

### Trying it with two players

1. Boot two Simulators (e.g. iPhone 16 and iPhone 16 Pro) and run the app on both.
2. On each, use **Quick sign-in for testing** with a different name.
3. On the first, pick a timeframe and tap **Create invite code**. On the second, enter the code and tap **Join**. Both hands are dealt.
4. Play a card from the Hand tab, then answer it from the other Simulator's Inbox.

### Sign in with Apple and push notifications

Both need a paid Apple Developer account and a signed build.

1. In the Apple Developer portal, enable **Sign in with Apple** and **Push Notifications** for the App ID `com.jamesshah.ldrcards` (or your own bundle ID; update `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` and `APPLE_BUNDLE_ID` in Convex to match).
2. Create `ios/LDRCards/Config/Local.xcconfig`:
   ```
   DEVELOPMENT_TEAM = ABCDE12345
   CODE_SIGN_ENTITLEMENTS = Support/LDRCards.entitlements
   ```
3. Create an APNs auth key (Keys, then +, then Apple Push Notifications service) and set the `APNS_*` variables above in Convex.
4. Run `xcodegen generate` and build to a real device. Debug builds register as `sandbox`, Release builds as `production`.
