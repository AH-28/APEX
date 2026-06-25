import type { FastifyInstance } from 'fastify';
import type { DB } from '../db.js';
import { login, signup } from '../auth.js';

export function authRoutes(app: FastifyInstance, db: DB) {
  app.post<{ Body: { email: string; password: string; displayName?: string } }>(
    '/auth/signup',
    {
      schema: {
        body: {
          type: 'object',
          required: ['email', 'password'],
          properties: {
            email: { type: 'string' },
            password: { type: 'string' },
            displayName: { type: 'string' },
          },
        },
      },
    },
    async (req) => signup(db, req.body.email, req.body.password, req.body.displayName),
  );

  app.post<{ Body: { email: string; password: string } }>(
    '/auth/login',
    {
      schema: {
        body: {
          type: 'object',
          required: ['email', 'password'],
          properties: { email: { type: 'string' }, password: { type: 'string' } },
        },
      },
    },
    async (req) => login(db, req.body.email, req.body.password),
  );
}
