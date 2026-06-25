// Quest template seed data.
//
// A template is NOT a finished quest — it's a reusable pattern with typed
// variable slots. The AI (or the deterministic fallback) fills the slots,
// which is how ~45 templates produce effectively unlimited distinct quests.
//
// Rules baked into every template: completable in 5-60 minutes, free,
// safe/legal, suitable for a broad audience, photo proof optional.

export interface TemplateVariable {
  description: string; // what the AI should generate for this slot
  examples: string[];  // few-shot examples + the fallback value pool
}

export interface QuestTemplate {
  id: string;
  category: Category;
  pattern: string;     // description pattern with {slots}
  titleHint: string;   // style guidance for the generated title
  variables: Record<string, TemplateVariable>;
  difficulty: 'Easy' | 'Medium' | 'Hard';
  estMinutes: number;
  requiresPhoto: boolean;
  indoorOk: boolean;
  minAgeRange?: string;
}

export const CATEGORIES = [
  'Adventure', 'Photography', 'Fitness', 'Learning', 'Social', 'Creativity',
  'Productivity', 'Food', 'Mindfulness', 'Nature', 'Kindness', 'Music',
] as const;
export type Category = (typeof CATEGORIES)[number];

export const TEMPLATES: QuestTemplate[] = [
  // ─── Photography ───────────────────────────────────────────────
  {
    id: 'photo-collection',
    category: 'Photography',
    pattern: 'Find and photograph {count} {subject} in different places.',
    titleHint: 'A two-word "hunter" style title, e.g. "Reflection Hunter"',
    variables: {
      count: { description: 'a small number as a word, two to five', examples: ['three', 'four', 'five'] },
      subject: {
        description: 'a visually interesting thing findable almost anywhere',
        examples: ['reflections', 'shadows with interesting shapes', 'circles', 'things that are red', 'textures', 'pairs of things'],
      },
    },
    difficulty: 'Easy', estMinutes: 20, requiresPhoto: true, indoorOk: true,
  },
  {
    id: 'photo-perspective',
    category: 'Photography',
    pattern: 'Photograph an everyday object from {angle} so it looks completely different.',
    titleHint: 'Playful title about seeing differently',
    variables: {
      angle: {
        description: 'an unusual camera angle or perspective',
        examples: ['directly below', 'ant level on the ground', 'extremely close up', 'through another object', 'its own shadow'],
      },
    },
    difficulty: 'Easy', estMinutes: 10, requiresPhoto: true, indoorOk: true,
  },
  {
    id: 'photo-golden-moment',
    category: 'Photography',
    pattern: 'Capture a photo that shows {concept} without showing any people.',
    titleHint: 'Short evocative title',
    variables: {
      concept: {
        description: 'an abstract feeling or idea to express in a photo',
        examples: ['quiet', 'motion', 'time passing', 'warmth', 'contrast', 'home'],
      },
    },
    difficulty: 'Medium', estMinutes: 25, requiresPhoto: true, indoorOk: true,
  },
  // ─── Adventure ─────────────────────────────────────────────────
  {
    id: 'adventure-new-route',
    category: 'Adventure',
    pattern: 'Take a walk using a route you have never used before and find {target} along the way.',
    titleHint: 'Explorer style title',
    variables: {
      target: {
        description: 'something simple to spot on a walk',
        examples: ['the oldest-looking building', 'an interesting door', 'a place you would like to revisit', 'something that surprises you'],
      },
    },
    difficulty: 'Easy', estMinutes: 30, requiresPhoto: true, indoorOk: false,
  },
  {
    id: 'adventure-visit-place',
    category: 'Adventure',
    pattern: 'Visit a {place} near you that you have never been inside, and spend at least ten minutes there.',
    titleHint: 'Discovery style title',
    variables: {
      place: {
        description: 'a free public place most towns have',
        examples: ['public library', 'park', 'local market', 'community centre', 'historic spot'],
      },
    },
    difficulty: 'Medium', estMinutes: 40, requiresPhoto: true, indoorOk: false,
  },
  {
    id: 'adventure-micro-quest',
    category: 'Adventure',
    pattern: 'Let chance pick your path: flip a coin at every corner for {duration} minutes (heads = left, tails = right) and see where you end up. Stay in areas you know are safe.',
    titleHint: 'Randomness/destiny themed title',
    variables: {
      duration: { description: 'a number of minutes between 10 and 20', examples: ['10', '15', '20'] },
    },
    difficulty: 'Medium', estMinutes: 25, requiresPhoto: true, indoorOk: false,
  },
  // ─── Fitness ───────────────────────────────────────────────────
  {
    id: 'fitness-mini-challenge',
    category: 'Fitness',
    pattern: 'Do {reps} {exercise} spread across the day — no need to do them all at once.',
    titleHint: 'Energetic challenge title',
    variables: {
      reps: { description: 'an achievable total count', examples: ['30', '40', '50'] },
      exercise: {
        description: 'a simple bodyweight exercise needing no equipment',
        examples: ['squats', 'wall push-ups', 'lunges', 'calf raises', 'star jumps'],
      },
    },
    difficulty: 'Easy', estMinutes: 10, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'fitness-walk-goal',
    category: 'Fitness',
    pattern: 'Go for a {duration}-minute walk while {twist}.',
    titleHint: 'Walking themed title',
    variables: {
      duration: { description: 'minutes between 15 and 40', examples: ['15', '20', '30'] },
      twist: {
        description: 'a small mindful or fun twist to add to the walk',
        examples: ['counting how many dogs you see', 'only taking streets you rarely use', 'listening to a full album', 'noticing five sounds you usually ignore'],
      },
    },
    difficulty: 'Easy', estMinutes: 30, requiresPhoto: false, indoorOk: false,
  },
  {
    id: 'fitness-balance',
    category: 'Fitness',
    pattern: 'Practice {skill} for ten minutes and see how much you improve between your first and last attempt.',
    titleHint: 'Skill progress title',
    variables: {
      skill: {
        description: 'a simple physical skill that shows quick progress',
        examples: ['standing on one leg with eyes closed', 'touching your toes', 'holding a plank', 'jumping rope (real or imaginary)'],
      },
    },
    difficulty: 'Medium', estMinutes: 12, requiresPhoto: false, indoorOk: true,
  },
  // ─── Learning ──────────────────────────────────────────────────
  {
    id: 'learning-one-thing',
    category: 'Learning',
    pattern: 'Learn one surprising thing about {topic} and write it down in your own words.',
    titleHint: 'Curiosity themed title',
    variables: {
      topic: {
        description: 'a specific, interesting topic — not a broad field',
        examples: ['how octopuses sleep', 'the history of your street name', 'why the sky is blue', 'how QR codes work', 'a country you cannot place on a map'],
      },
    },
    difficulty: 'Easy', estMinutes: 15, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'learning-teach-back',
    category: 'Learning',
    pattern: 'Spend fifteen minutes learning about {topic}, then explain it out loud in under a minute as if teaching a friend.',
    titleHint: 'Teacher/professor themed title',
    variables: {
      topic: {
        description: 'a concrete concept that can be grasped in 15 minutes',
        examples: ['how tides work', 'what inflation actually is', 'how noise-cancelling headphones work', 'why leaves change colour'],
      },
    },
    difficulty: 'Medium', estMinutes: 20, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'learning-word-day',
    category: 'Learning',
    pattern: 'Learn the word for {word} in {language} and use it in a sentence three times today.',
    titleHint: 'Polyglot themed title',
    variables: {
      word: { description: 'a common everyday word', examples: ['thank you', 'adventure', 'delicious', 'friend', 'sunset'] },
      language: { description: 'a language the user probably does not speak', examples: ['Japanese', 'Swahili', 'Portuguese', 'Korean', 'Greek'] },
    },
    difficulty: 'Easy', estMinutes: 5, requiresPhoto: false, indoorOk: true,
  },
  // ─── Social ────────────────────────────────────────────────────
  {
    id: 'social-reach-out',
    category: 'Social',
    pattern: 'Message or call someone you have not spoken to in a while and ask them about {topic}.',
    titleHint: 'Reconnection themed title',
    variables: {
      topic: {
        description: 'a warm, open conversation starter',
        examples: ['the best thing that happened to them this month', 'what they are excited about lately', 'a memory you share', 'what they are reading or watching'],
      },
    },
    difficulty: 'Easy', estMinutes: 15, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'social-compliment',
    category: 'Social',
    pattern: 'Give a genuine, specific compliment to {count} different people today.',
    titleHint: 'Positivity themed title',
    variables: {
      count: { description: 'two or three, as a word', examples: ['two', 'three'] },
    },
    difficulty: 'Easy', estMinutes: 5, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'social-ask-story',
    category: 'Social',
    pattern: 'Ask someone older than you to tell you about {subject}, and really listen.',
    titleHint: 'Storyteller themed title',
    variables: {
      subject: {
        description: 'a story prompt about their past',
        examples: ['their first job', 'what this area looked like when they were young', 'the best advice they ever received', 'a trip they will never forget'],
      },
    },
    difficulty: 'Medium', estMinutes: 20, requiresPhoto: false, indoorOk: true,
  },
  // ─── Creativity ────────────────────────────────────────────────
  {
    id: 'creative-make-with',
    category: 'Creativity',
    pattern: 'Create something using only {item} — anything counts: a sculpture, a picture, a tiny invention.',
    titleHint: 'Maker themed title',
    variables: {
      item: {
        description: 'common free household material(s)',
        examples: ['things from your recycling bin', 'paper and one pen', 'objects on your desk', 'aluminium foil', 'whatever is in your pockets or bag'],
      },
    },
    difficulty: 'Medium', estMinutes: 25, requiresPhoto: true, indoorOk: true,
  },
  {
    id: 'creative-tiny-story',
    category: 'Creativity',
    pattern: 'Write a six-word story about {theme}. Then write two more and pick your favourite.',
    titleHint: 'Writer themed title',
    variables: {
      theme: {
        description: 'an evocative everyday theme',
        examples: ['a missed bus', 'breakfast', 'an open window', 'the last text you received', 'a stranger on the street'],
      },
    },
    difficulty: 'Easy', estMinutes: 10, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'creative-doodle',
    category: 'Creativity',
    pattern: 'Draw {subject} without lifting your pen from the paper. Speed and ugliness are part of the fun.',
    titleHint: 'Artist themed title',
    variables: {
      subject: {
        description: 'a drawable subject nearby',
        examples: ['your own hand', 'the view from the nearest window', 'your shoe', 'the contents of your table', 'a face from memory'],
      },
    },
    difficulty: 'Easy', estMinutes: 10, requiresPhoto: true, indoorOk: true,
  },
  // ─── Productivity ──────────────────────────────────────────────
  {
    id: 'productivity-declutter',
    category: 'Productivity',
    pattern: 'Spend {duration} minutes decluttering {zone}. Before/after photos make it satisfying.',
    titleHint: 'Order/chaos themed title',
    variables: {
      duration: { description: 'minutes between 10 and 20', examples: ['10', '15', '20'] },
      zone: {
        description: 'one small specific area',
        examples: ['one drawer', 'your desktop (real or digital)', 'your phone home screen', 'one shelf', 'your downloads folder'],
      },
    },
    difficulty: 'Easy', estMinutes: 15, requiresPhoto: true, indoorOk: true,
  },
  {
    id: 'productivity-frog',
    category: 'Productivity',
    pattern: 'Pick the task you have been avoiding the longest and work on it for just {duration} minutes — a timer makes it official.',
    titleHint: 'Courage/dragon-slaying themed title',
    variables: {
      duration: { description: 'minutes between 10 and 25', examples: ['10', '15', '25'] },
    },
    difficulty: 'Medium', estMinutes: 20, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'productivity-tomorrow-self',
    category: 'Productivity',
    pattern: 'Do one small thing tonight that your tomorrow self will thank you for: {suggestion}, or your own idea.',
    titleHint: 'Time-travel themed title',
    variables: {
      suggestion: {
        description: 'a tiny preparation task for tomorrow',
        examples: ['lay out tomorrow’s clothes', 'prepare your bag', 'write tomorrow’s top three tasks', 'fill a water bottle and put it by your bed'],
      },
    },
    difficulty: 'Easy', estMinutes: 5, requiresPhoto: false, indoorOk: true,
  },
  // ─── Food ──────────────────────────────────────────────────────
  {
    id: 'food-new-twist',
    category: 'Food',
    pattern: 'Make a meal or snack you already know, but add {twist} you have never tried with it.',
    titleHint: 'Chef/experiment themed title',
    variables: {
      twist: {
        description: 'a simple twist using common ingredients',
        examples: ['a spice you rarely use', 'an unusual ingredient pairing', 'a different cooking method', 'plating it like a fancy restaurant'],
      },
    },
    difficulty: 'Easy', estMinutes: 30, requiresPhoto: true, indoorOk: true,
  },
  {
    id: 'food-blind-taste',
    category: 'Food',
    pattern: 'Eat something with your eyes closed and try to notice {count} flavours or textures you normally miss.',
    titleHint: 'Senses themed title',
    variables: {
      count: { description: 'three to five as a word', examples: ['three', 'four', 'five'] },
    },
    difficulty: 'Easy', estMinutes: 10, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'food-recipe-hunt',
    category: 'Food',
    pattern: 'Find a traditional recipe from {cuisine} and either cook a simple version with what you have, or plan exactly how you would.',
    titleHint: 'World traveller themed title',
    variables: {
      cuisine: {
        description: 'a world cuisine the user likely has not cooked',
        examples: ['Ethiopia', 'Peru', 'Vietnam', 'Morocco', 'Georgia (the country)'],
      },
    },
    difficulty: 'Medium', estMinutes: 45, requiresPhoto: true, indoorOk: true,
  },
  // ─── Mindfulness ───────────────────────────────────────────────
  {
    id: 'mindful-senses',
    category: 'Mindfulness',
    pattern: 'Sit somewhere for five quiet minutes and note {count} things you can {sense}.',
    titleHint: 'Calm/presence themed title',
    variables: {
      count: { description: 'three to ten as a word', examples: ['five', 'seven', 'ten'] },
      sense: { description: 'one sense to focus on', examples: ['hear', 'see in one colour', 'feel (textures, air, temperature)', 'smell'] },
    },
    difficulty: 'Easy', estMinutes: 8, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'mindful-unplug',
    category: 'Mindfulness',
    pattern: 'Spend {duration} minutes completely offline — your only job is {activity}.',
    titleHint: 'Digital detox themed title',
    variables: {
      duration: { description: 'minutes between 20 and 45', examples: ['20', '30', '45'] },
      activity: {
        description: 'a screen-free activity',
        examples: ['watching the sky', 'stretching', 'sitting with a hot drink and doing nothing', 'tidying with music on'],
      },
    },
    difficulty: 'Medium', estMinutes: 30, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'mindful-gratitude',
    category: 'Mindfulness',
    pattern: 'Write down three things you are grateful for today — but they all have to be about {theme}.',
    titleHint: 'Gratitude themed title',
    variables: {
      theme: {
        description: 'a narrow, unexpected gratitude theme',
        examples: ['things smaller than your hand', 'things that happened before noon', 'people you have never met', 'sounds', 'things you usually complain about'],
      },
    },
    difficulty: 'Easy', estMinutes: 10, requiresPhoto: false, indoorOk: true,
  },
  // ─── Nature ────────────────────────────────────────────────────
  {
    id: 'nature-spotter',
    category: 'Nature',
    pattern: 'Find {count} different kinds of {target} near where you live.',
    titleHint: 'Naturalist themed title',
    variables: {
      count: { description: 'three to five as a word', examples: ['three', 'four', 'five'] },
      target: {
        description: 'a nature category findable in cities too',
        examples: ['leaves with different shapes', 'birds', 'clouds', 'insects', 'plants growing where they should not'],
      },
    },
    difficulty: 'Easy', estMinutes: 20, requiresPhoto: true, indoorOk: false,
  },
  {
    id: 'nature-sky-watch',
    category: 'Nature',
    pattern: 'Watch the {event} today and photograph the exact moment you like most.',
    titleHint: 'Sky themed title',
    variables: {
      event: { description: 'a daily sky event', examples: ['sunset', 'sunrise', 'clouds for ten full minutes', 'moon rising'] },
    },
    difficulty: 'Easy', estMinutes: 15, requiresPhoto: true, indoorOk: false,
  },
  // ─── Kindness ──────────────────────────────────────────────────
  {
    id: 'kindness-small-act',
    category: 'Kindness',
    pattern: 'Do one small anonymous act of kindness today: {idea}, or invent your own.',
    titleHint: 'Secret hero themed title',
    variables: {
      idea: {
        description: 'a free, anonymous kind act',
        examples: ['leave a kind sticky note where someone will find it', 'pick up three pieces of litter', 'leave a glowing review for a small local business', 'let someone go ahead of you'],
      },
    },
    difficulty: 'Easy', estMinutes: 10, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'kindness-thank-you',
    category: 'Kindness',
    pattern: 'Write a short thank-you message to {person} telling them exactly what they did and why it mattered.',
    titleHint: 'Gratitude/letter themed title',
    variables: {
      person: {
        description: 'a type of person who deserves overdue thanks',
        examples: ['a teacher who influenced you', 'a friend who showed up for you', 'a family member you rarely thank', 'someone who helped you this year'],
      },
    },
    difficulty: 'Medium', estMinutes: 15, requiresPhoto: false, indoorOk: true,
  },
  // ─── Music ─────────────────────────────────────────────────────
  {
    id: 'music-discover',
    category: 'Music',
    pattern: 'Listen to a full song in {genre} — a style you never normally play — and note one thing you genuinely liked.',
    titleHint: 'Music explorer themed title',
    variables: {
      genre: {
        description: 'a genre most people have not explored',
        examples: ['Mongolian throat singing', 'bossa nova', '1920s jazz', 'Afrobeat', 'baroque', 'city pop'],
      },
    },
    difficulty: 'Easy', estMinutes: 10, requiresPhoto: false, indoorOk: true,
  },
  {
    id: 'music-soundtrack',
    category: 'Music',
    pattern: 'Build a three-song soundtrack for {moment} and listen to it during that moment.',
    titleHint: 'Movie soundtrack themed title',
    variables: {
      moment: {
        description: 'an ordinary daily moment to soundtrack',
        examples: ['your walk home', 'cooking dinner', 'the first ten minutes of your morning', 'watching the sunset'],
      },
    },
    difficulty: 'Easy', estMinutes: 15, requiresPhoto: false, indoorOk: true,
  },
];
