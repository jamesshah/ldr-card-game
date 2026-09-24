export type SeedCard = {
  slug: string;
  title: string;
  body: string;
  category: string;
  kind: "action" | "counter";
};

const action = (slug: string, category: string, title: string, body: string): SeedCard => ({
  slug,
  title,
  body,
  category,
  kind: "action",
});

const counter = (slug: string, title: string, body: string): SeedCard => ({
  slug,
  title,
  body,
  category: "Counter",
  kind: "counter",
});

/** The original LDR deck: 54 action cards and 6 counter cards. */
export const SEED_CARDS: SeedCard[] = [
  // Calls
  action("call-now", "Calls", "Video call me right now", "Drop what you're doing (safely) and call me within 15 minutes."),
  action("call-wake-up", "Calls", "Wake-up call", "Call me to wake me up at a time I choose, even if it's the middle of your night."),
  action("call-goodnight", "Calls", "Fall asleep on the phone", "Stay on the call until one of us falls asleep."),
  action("call-walk", "Calls", "Take me on a walk", "Go for a 20-minute walk and show me everything on video."),
  action("call-cook", "Calls", "Cook with me", "Pick a recipe we both make at the same time on a video call."),
  action("call-no-phone", "Calls", "Undivided attention", "Our next call is 30 minutes with no other screens and no multitasking."),
  action("call-tour", "Calls", "Give me the tour", "Show me somewhere in your city I've never seen, live."),

  // Voice & video
  action("voice-30", "Voice & Video", "30-second voice note", "Send me a 30-second voice note about your day, unedited."),
  action("voice-song", "Voice & Video", "Sing it to me", "Send a voice note of you singing the chorus of a song I pick."),
  action("voice-read", "Voice & Video", "Bedtime story", "Record yourself reading me a chapter, a poem, or a story you make up."),
  action("voice-reasons", "Voice & Video", "Three reasons", "Record a voice note with three reasons you'd rather be here with me."),
  action("video-morning", "Voice & Video", "Good morning video", "Send a video the moment you wake up, bedhead and all."),
  action("video-dance", "Voice & Video", "Dance break", "Send a 15-second video of you dancing to a song I choose."),
  action("voice-accent", "Voice & Video", "Say it in an accent", "Send a voice note telling me you miss me in your best accent."),

  // Photos
  action("photo-view", "Photos", "Photo of your view", "Send a photo of exactly what you're looking at right now. No retakes."),
  action("photo-outfit", "Photos", "Outfit check", "Send a full outfit photo of what you're wearing today."),
  action("photo-meal", "Photos", "What's for dinner", "Send a photo of your next meal before you take a bite."),
  action("photo-old", "Photos", "Throwback", "Send a photo of you from before we met, with the story behind it."),
  action("photo-us", "Photos", "Favorite photo of us", "Send your favorite photo of us and tell me why it's the one."),
  action("photo-sky", "Photos", "Same sky", "Send a photo of your sky tonight. I'll send mine."),
  action("photo-selfie-now", "Photos", "Selfie, right now", "Send a selfie within 5 minutes, wherever you are."),
  action("photo-desk", "Photos", "Show me your space", "Send a photo of where you're sitting, exactly as it is."),

  // Deliveries & surprises
  action("deliver-snack", "Deliveries", "Order me a surprise delivery", "Send something to my door. I don't get to pick what."),
  action("deliver-coffee", "Deliveries", "Buy me a coffee", "Get me a coffee or treat delivered, or send a gift card for my usual order."),
  action("deliver-letter", "Deliveries", "Handwritten letter", "Write me a real letter and post it this week."),
  action("deliver-flowers", "Deliveries", "Flowers, no occasion", "Send me flowers or a plant for no reason at all."),
  action("deliver-care", "Deliveries", "Care package", "Put together a small box of things that remind you of me and ship it."),
  action("deliver-playlist", "Deliveries", "Make me a playlist", "Build a playlist of at least 10 songs for me, with a title."),
  action("deliver-wallpaper", "Deliveries", "Set my wallpaper", "Pick a new lock screen for me. I have to keep it for a week."),

  // Together apart
  action("sync-movie", "Together Apart", "Watch the same movie tonight", "Start a movie at the same time and text reactions the whole way through."),
  action("sync-game", "Together Apart", "Game night", "Play an online game with me tonight. Loser plans the next date."),
  action("sync-dinner", "Together Apart", "Dinner date", "Dress up and eat dinner together on video, candles included."),
  action("sync-book", "Together Apart", "Book club for two", "Start the same book this week and discuss the first chapter."),
  action("sync-workout", "Together Apart", "Sweat together", "Do a 20-minute workout with me on video."),
  action("sync-stars", "Together Apart", "Stargazing date", "Go outside at the same time tonight and find the moon together."),
  action("sync-quiz", "Together Apart", "36 questions", "Answer five deep questions I pick on our next call."),
  action("sync-countdown", "Together Apart", "Plan the next visit", "Spend 20 minutes with me planning our next time together, dates and all."),

  // Sweet
  action("sweet-compliment", "Sweet", "Compliment storm", "Text me five compliments in a row without stopping."),
  action("sweet-memory", "Sweet", "Our best day", "Write out your favorite memory of us in as much detail as you can."),
  action("sweet-future", "Sweet", "Someday list", "Tell me three things you want us to do once we're in the same place."),
  action("sweet-miss", "Sweet", "What I miss most", "Tell me the one small thing about me you miss the most."),
  action("sweet-brag", "Sweet", "Brag about me", "Tell a friend or family member something great about me, and show me."),
  action("sweet-note", "Sweet", "Hide a note", "Hide a note in my next care package, email, or chat for me to find later."),
  action("sweet-hug", "Sweet", "Long-distance hug", "Hug a pillow for a full minute on video, with commitment."),

  // Playful
  action("play-outfit", "Playful", "Choose my outfit", "You pick what I wear on our next call."),
  action("play-dare", "Playful", "Truth or dare", "I ask one truth or give one dare. You have to pick one."),
  action("play-emoji", "Playful", "Emoji only", "For the next hour you can only text me in emoji."),
  action("play-rename", "Playful", "New contact name", "I pick your new name in my phone and you have to pick mine."),
  action("play-impression", "Playful", "Do an impression", "Do your best impression of me on our next call."),
  action("play-draw", "Playful", "Draw us", "Draw a picture of us together and send it, however bad."),
  action("play-guess", "Playful", "Guess my day", "Guess three things I did today. Get one wrong and you owe me a voice note."),
  action("play-status", "Playful", "Public declaration", "Post or share something sweet about me where your friends will see it."),
  action("play-timezone", "Playful", "Live on my time", "Set a clock to my time zone for a day and send me a photo of it."),
  action("play-yes", "Playful", "Yes hour", "For the next hour you say yes to every (reasonable) request I send."),

  // Counters
  counter("counter-shut-down", "Shut it down", "Knock a card played on you out of the game. It's gone for good."),
  counter("counter-not-today", "Not today", "Knock a card played on you out of the game, no questions asked."),
  counter("counter-bad-signal", "Bad signal", "Blame the Wi-Fi. The card played on you is knocked out of the game."),
  counter("counter-time-zone", "Wrong time zone", "It's the middle of the night somewhere. The card played on you is out."),
  counter("counter-veto", "Veto", "Use your veto. The card played on you is out of the game."),
  counter("counter-rain-check", "Rain check, forever", "Politely decline. The card played on you is out of the game."),
];
