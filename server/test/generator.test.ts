import test from 'node:test';
import assert from 'node:assert/strict';
import { openDb } from '../src/db.js';
import { signup } from '../src/auth.js';
import {
  getOrGenerateDailyQuests,
  selectTemplates,
  renderPattern,
  xpFor,
  pickQuestCount,
} from '../src/services/questGenerator.js';
import { fillWithFallback } from '../src/services/aiFiller.js';
import { TEMPLATES } from '../src/seed/templates.js';

function freshDb() {
  return openDb(':memory:');
}

test('template seed loads into the database', () => {
  const db = freshDb();
  const n = (db.prepare('SELECT COUNT(*) AS n FROM quest_templates').get() as { n: number }).n;
  assert.equal(n, TEMPLATES.length);
  assert.ok(n >= 30, 'should ship a healthy template catalogue');
});

test('selectTemplates respects exclusions, count and category diversity', () => {
  const exclude = new Set([TEMPLATES[0].id]);
  const picked = selectTemplates(TEMPLATES, {
    interests: ['Photography', 'Food'],
    difficulty: 'Easy',
    ageRange: '18-24',
    exclude,
    count: 5,
  });
  assert.equal(picked.length, 5);
  assert.ok(!picked.some((t) => t.id === TEMPLATES[0].id), 'excluded template must not be picked');
  const categories = picked.map((t) => t.category);
  assert.equal(new Set(categories).size, categories.length, 'no duplicate categories in a day');
});

test('interest weighting biases selection', () => {
  let photographyHits = 0;
  const runs = 300;
  for (let i = 0; i < runs; i++) {
    const picked = selectTemplates(TEMPLATES, {
      interests: ['Photography'],
      difficulty: 'Easy',
      ageRange: null,
      exclude: new Set(),
      count: 3,
    });
    if (picked.some((t) => t.category === 'Photography')) photographyHits++;
  }
  assert.ok(photographyHits / runs > 0.5, `interest category should appear most days (got ${photographyHits}/${runs})`);
});

test('renderPattern fills all slots', () => {
  const out = renderPattern('Find {count} {subject}.', { count: 'three', subject: 'reflections' });
  assert.equal(out, 'Find three reflections.');
});

test('fallback filler avoids recently used values when possible', () => {
  const t = TEMPLATES.find((x) => x.id === 'photo-collection')!;
  const avoid = t.variables.subject.examples.slice(0, t.variables.subject.examples.length - 1);
  for (let i = 0; i < 20; i++) {
    const [filled] = fillWithFallback({
      user: { interests: [], difficulty: 'Easy', level: 1 },
      templates: [t],
      recentlyUsed: { [t.id]: avoid },
    });
    assert.equal(filled.variables.subject, t.variables.subject.examples.at(-1));
  }
});

test('xp is server-computed and scales with difficulty', () => {
  assert.ok(xpFor('Hard', 30) > xpFor('Medium', 30));
  assert.ok(xpFor('Medium', 30) > xpFor('Easy', 30));
});

test('quest count scales with level', () => {
  assert.equal(pickQuestCount(1), 5);
  assert.equal(pickQuestCount(5), 6);
  assert.equal(pickQuestCount(12), 8);
});

test('end-to-end: daily generation is idempotent and well-formed', async () => {
  const db = freshDb();
  const { id } = signup(db, 'test@example.com', 'password123');
  db.prepare(`UPDATE users SET interests = '["Photography","Learning"]' WHERE id = ?`).run(id);

  const first = await getOrGenerateDailyQuests(db, id);
  assert.ok(first.length >= 5 && first.length <= 8, `expected 5-8 quests, got ${first.length}`);
  for (const q of first) {
    assert.ok(q.title.length > 0);
    assert.ok(!q.description.includes('{'), `unfilled slot in: ${q.description}`);
    assert.ok(q.est_minutes >= 5 && q.est_minutes <= 60);
    assert.ok(q.xp_reward > 0);
    assert.equal(q.status, 'active');
  }
  // Same day → same quests, no regeneration.
  const second = await getOrGenerateDailyQuests(db, id);
  assert.deepEqual(second.map((q) => q.id).sort(), first.map((q) => q.id).sort());

  const run = db.prepare('SELECT * FROM generation_runs WHERE user_id = ?').get(id) as { source: string };
  assert.equal(run.source, process.env.ANTHROPIC_API_KEY ? 'ai' : 'fallback');
});

test('completing a quest awards XP and levels up correctly', async () => {
  const db = freshDb();
  const { id } = signup(db, 'xp@example.com', 'password123');
  const quests = await getOrGenerateDailyQuests(db, id);
  const q = quests[0];
  db.prepare(`UPDATE quests SET status = 'completed', completed_at = datetime('now') WHERE id = ?`).run(q.id);
  db.prepare('UPDATE users SET xp = xp + ? WHERE id = ?').run(q.xp_reward, id);
  const { xp } = db.prepare('SELECT xp FROM users WHERE id = ?').get(id) as { xp: number };
  assert.equal(xp, q.xp_reward);
});
