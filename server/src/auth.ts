import { randomUUID } from 'node:crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import type { FastifyReply, FastifyRequest } from 'fastify';
import type { DB } from './db.js';
import { config } from './config.js';

export interface AuthedUser { id: string; email: string; }

export function signup(db: DB, email: string, password: string, displayName?: string) {
  const normalized = email.trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalized)) throw httpError(400, 'invalid email');
  if (password.length < 8) throw httpError(400, 'password must be at least 8 characters');
  const exists = db.prepare('SELECT 1 FROM users WHERE email = ?').get(normalized);
  if (exists) throw httpError(409, 'email already registered');

  const id = randomUUID();
  db.prepare(
    'INSERT INTO users (id, email, password_hash, display_name) VALUES (?, ?, ?, ?)',
  ).run(id, normalized, bcrypt.hashSync(password, 10), displayName ?? null);
  return { id, email: normalized, token: issueToken(id, normalized) };
}

export function login(db: DB, email: string, password: string) {
  const normalized = email.trim().toLowerCase();
  const user = db.prepare('SELECT id, email, password_hash FROM users WHERE email = ?').get(normalized) as
    | { id: string; email: string; password_hash: string }
    | undefined;
  if (!user || !bcrypt.compareSync(password, user.password_hash)) {
    throw httpError(401, 'invalid email or password');
  }
  return { id: user.id, email: user.email, token: issueToken(user.id, user.email) };
}

export function issueToken(id: string, email: string): string {
  return jwt.sign({ sub: id, email }, config.jwtSecret, { expiresIn: '30d' });
}

/** Fastify preHandler: verifies the Bearer token and attaches request.user. */
export function requireAuth(req: FastifyRequest, reply: FastifyReply, done: (err?: Error) => void) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    reply.code(401).send({ error: 'missing bearer token' });
    return;
  }
  try {
    const payload = jwt.verify(header.slice(7), config.jwtSecret) as { sub: string; email: string };
    (req as FastifyRequest & { user: AuthedUser }).user = { id: payload.sub, email: payload.email };
    done();
  } catch {
    reply.code(401).send({ error: 'invalid or expired token' });
  }
}

export function httpError(status: number, message: string): Error & { statusCode: number } {
  const err = new Error(message) as Error & { statusCode: number };
  err.statusCode = status;
  return err;
}
