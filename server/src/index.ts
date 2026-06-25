import Fastify from 'fastify';
import { openDb } from './db.js';
import { config } from './config.js';
import { authRoutes } from './routes/auth.routes.js';
import { userRoutes } from './routes/user.routes.js';
import { questRoutes } from './routes/quest.routes.js';

export function buildApp(dbPath?: string) {
  const db = openDb(dbPath);
  const app = Fastify({ logger: true, bodyLimit: 15 * 1024 * 1024 });

  // Permissive CORS so the Flutter web build can talk to the API in dev.
  app.addHook('onSend', async (_req, reply) => {
    reply.header('Access-Control-Allow-Origin', '*');
    reply.header('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    reply.header('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
  });
  app.options('*', async (_req, reply) => reply.code(204).send());

  app.get('/health', async () => ({ ok: true, ai: Boolean(config.anthropicApiKey) }));

  authRoutes(app, db);
  userRoutes(app, db);
  questRoutes(app, db);
  return { app, db };
}

// Start only when run directly (tests import buildApp instead).
if (process.argv[1] && import.meta.url.endsWith(process.argv[1].split('/').pop()!)) {
  const { app } = buildApp();
  app.listen({ port: config.port, host: '0.0.0.0' }).then(() => {
    console.log(`APEX server on :${config.port} — AI ${config.anthropicApiKey ? 'enabled' : 'DISABLED (fallback mode, set ANTHROPIC_API_KEY)'}`);
  });
}
