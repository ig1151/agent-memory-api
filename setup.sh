#!/bin/bash
set -e

echo "🚀 Setting up Agent Memory API..."

mkdir -p src/routes

cat > package.json << 'ENDPACKAGE'
{
  "name": "agent-memory-api",
  "version": "1.0.0",
  "description": "Persistent memory and context storage for AI agents — store, retrieve and search memories by session.",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "dev": "ts-node-dev --respawn --transpile-only src/index.ts",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "axios": "^1.6.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "express-rate-limit": "^7.1.5",
    "helmet": "^7.1.0",
    "joi": "^17.11.0",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "@types/compression": "^1.7.5",
    "@types/cors": "^2.8.17",
    "@types/express": "^4.17.21",
    "@types/node": "^20.10.0",
    "@types/uuid": "^9.0.7",
    "ts-node-dev": "^2.0.0",
    "typescript": "^5.3.2"
  }
}
ENDPACKAGE

cat > tsconfig.json << 'ENDTSCONFIG'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
ENDTSCONFIG

cat > render.yaml << 'ENDRENDER'
services:
  - type: web
    name: agent-memory-api
    env: node
    buildCommand: npm install && npm run build
    startCommand: node dist/index.js
    healthCheckPath: /v1/health
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: 10000
ENDRENDER

cat > .gitignore << 'ENDGITIGNORE'
node_modules/
dist/
.env
*.log
ENDGITIGNORE

cat > src/logger.ts << 'ENDLOGGER'
export const logger = {
  info: (obj: unknown, msg?: string) =>
    console.log(JSON.stringify({ level: 'info', ...(typeof obj === 'object' ? obj : { data: obj }), msg })),
  warn: (obj: unknown, msg?: string) =>
    console.warn(JSON.stringify({ level: 'warn', ...(typeof obj === 'object' ? obj : { data: obj }), msg })),
  error: (obj: unknown, msg?: string) =>
    console.error(JSON.stringify({ level: 'error', ...(typeof obj === 'object' ? obj : { data: obj }), msg })),
};
ENDLOGGER

cat > src/types.ts << 'ENDTYPES'
export interface Memory {
  id: string;
  session_id: string;
  content: string;
  role: 'user' | 'assistant' | 'system';
  metadata?: Record<string, unknown>;
  created_at: string;
  tags?: string[];
}

export interface Session {
  id: string;
  created_at: string;
  updated_at: string;
  memory_count: number;
  metadata?: Record<string, unknown>;
}
ENDTYPES

cat > src/store.ts << 'ENDSTORE'
import { Memory, Session } from './types';

const sessions = new Map<string, Session>();
const memories = new Map<string, Memory[]>();
const MAX_MEMORIES_PER_SESSION = 1000;

export const store = {
  // Session operations
  getOrCreateSession(sessionId: string, metadata?: Record<string, unknown>): Session {
    if (!sessions.has(sessionId)) {
      const session: Session = {
        id: sessionId,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        memory_count: 0,
        metadata,
      };
      sessions.set(sessionId, session);
      memories.set(sessionId, []);
    }
    return sessions.get(sessionId)!;
  },

  getSession(sessionId: string): Session | undefined {
    return sessions.get(sessionId);
  },

  updateSession(sessionId: string, patch: Partial<Session>): void {
    const session = sessions.get(sessionId);
    if (session) sessions.set(sessionId, { ...session, ...patch, updated_at: new Date().toISOString() });
  },

  deleteSession(sessionId: string): boolean {
    memories.delete(sessionId);
    return sessions.delete(sessionId);
  },

  listSessions(): Session[] {
    return Array.from(sessions.values()).sort((a, b) =>
      new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime()
    );
  },

  // Memory operations
  addMemory(memory: Memory): Memory {
    const sessionMemories = memories.get(memory.session_id) ?? [];
    sessionMemories.push(memory);
    if (sessionMemories.length > MAX_MEMORIES_PER_SESSION) {
      sessionMemories.shift();
    }
    memories.set(memory.session_id, sessionMemories);

    const session = sessions.get(memory.session_id);
    if (session) {
      sessions.set(memory.session_id, {
        ...session,
        memory_count: sessionMemories.length,
        updated_at: new Date().toISOString(),
      });
    }

    return memory;
  },

  getMemories(sessionId: string, limit = 50, role?: string): Memory[] {
    const sessionMemories = memories.get(sessionId) ?? [];
    const filtered = role ? sessionMemories.filter(m => m.role === role) : sessionMemories;
    return filtered.slice(-limit);
  },

  searchMemories(sessionId: string, query: string, limit = 10): Memory[] {
    const sessionMemories = memories.get(sessionId) ?? [];
    const queryLower = query.toLowerCase();
    const queryWords = queryLower.split(/\s+/).filter(w => w.length > 2);

    const scored = sessionMemories.map(memory => {
      const contentLower = memory.content.toLowerCase();
      let score = 0;
      for (const word of queryWords) {
        if (contentLower.includes(word)) score += 1;
      }
      if (contentLower.includes(queryLower)) score += 3;
      const tagScore = memory.tags?.some(t => t.toLowerCase().includes(queryLower)) ? 2 : 0;
      return { memory, score: score + tagScore };
    });

    return scored
      .filter(s => s.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map(s => s.memory);
  },

  deleteMemory(sessionId: string, memoryId: string): boolean {
    const sessionMemories = memories.get(sessionId) ?? [];
    const index = sessionMemories.findIndex(m => m.id === memoryId);
    if (index === -1) return false;
    sessionMemories.splice(index, 1);
    memories.set(sessionId, sessionMemories);
    const session = sessions.get(sessionId);
    if (session) {
      sessions.set(sessionId, { ...session, memory_count: sessionMemories.length, updated_at: new Date().toISOString() });
    }
    return true;
  },

  totalSessions(): number {
    return sessions.size;
  },

  totalMemories(): number {
    let count = 0;
    for (const mems of memories.values()) count += mems.length;
    return count;
  },
};
ENDSTORE

cat > src/routes/memory.ts << 'ENDMEMORY'
import { Router, Request, Response } from 'express';
import Joi from 'joi';
import { v4 as uuidv4 } from 'uuid';
import { store } from '../store';
import { logger } from '../logger';
import { Memory } from '../types';

const router = Router();

const addMemorySchema = Joi.object({
  content: Joi.string().min(1).max(10000).required(),
  role: Joi.string().valid('user', 'assistant', 'system').default('user'),
  tags: Joi.array().items(Joi.string().max(50)).max(10).optional(),
  metadata: Joi.object().optional(),
});

const searchSchema = Joi.object({
  session_id: Joi.string().min(1).max(200).required(),
  query: Joi.string().min(1).max(500).required(),
  limit: Joi.number().integer().min(1).max(50).default(10),
});

const batchSchema = Joi.object({
  memories: Joi.array().items(Joi.object({
    content: Joi.string().min(1).max(10000).required(),
    role: Joi.string().valid('user', 'assistant', 'system').default('user'),
    tags: Joi.array().items(Joi.string().max(50)).max(10).optional(),
    metadata: Joi.object().optional(),
  })).min(1).max(50).required(),
});

// POST /v1/memory/:session_id — add memory
router.post('/:session_id', (req: Request, res: Response) => {
  const { error, value } = addMemorySchema.validate(req.body);
  if (error) {
    res.status(400).json({ error: 'Validation failed', details: error.details[0].message });
    return;
  }

  const sessionId = req.params.session_id;
  store.getOrCreateSession(sessionId);

  const memory: Memory = {
    id: uuidv4(),
    session_id: sessionId,
    content: value.content,
    role: value.role,
    tags: value.tags,
    metadata: value.metadata,
    created_at: new Date().toISOString(),
  };

  store.addMemory(memory);
  logger.info({ sessionId, memoryId: memory.id, role: memory.role }, 'Memory added');

  res.status(201).json(memory);
});

// POST /v1/memory/:session_id/batch — add multiple memories
router.post('/:session_id/batch', (req: Request, res: Response) => {
  const { error, value } = batchSchema.validate(req.body);
  if (error) {
    res.status(400).json({ error: 'Validation failed', details: error.details[0].message });
    return;
  }

  const sessionId = req.params.session_id;
  store.getOrCreateSession(sessionId);

  const added: Memory[] = [];
  for (const item of value.memories) {
    const memory: Memory = {
      id: uuidv4(),
      session_id: sessionId,
      content: item.content,
      role: item.role,
      tags: item.tags,
      metadata: item.metadata,
      created_at: new Date().toISOString(),
    };
    store.addMemory(memory);
    added.push(memory);
  }

  logger.info({ sessionId, count: added.length }, 'Batch memories added');
  res.status(201).json({ added: added.length, memories: added });
});

// GET /v1/memory/:session_id — retrieve memories
router.get('/:session_id', (req: Request, res: Response) => {
  const sessionId = req.params.session_id;
  const session = store.getSession(sessionId);
  if (!session) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }

  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const role = req.query.role as string | undefined;
  const memories = store.getMemories(sessionId, limit, role);

  res.json({
    session_id: sessionId,
    count: memories.length,
    total_in_session: session.memory_count,
    memories,
  });
});

// POST /v1/memory/search — search memories
router.post('/search', (req: Request, res: Response) => {
  const { error, value } = searchSchema.validate(req.body);
  if (error) {
    res.status(400).json({ error: 'Validation failed', details: error.details[0].message });
    return;
  }

  const session = store.getSession(value.session_id);
  if (!session) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }

  const results = store.searchMemories(value.session_id, value.query, value.limit);
  logger.info({ sessionId: value.session_id, query: value.query, results: results.length }, 'Memory search complete');

  res.json({
    session_id: value.session_id,
    query: value.query,
    count: results.length,
    memories: results,
  });
});

// GET /v1/memory/:session_id/session — get session info
router.get('/:session_id/session', (req: Request, res: Response) => {
  const session = store.getSession(req.params.session_id);
  if (!session) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }
  res.json(session);
});

// DELETE /v1/memory/:session_id — clear session
router.delete('/:session_id', (req: Request, res: Response) => {
  const deleted = store.deleteSession(req.params.session_id);
  if (!deleted) {
    res.status(404).json({ error: 'Session not found' });
    return;
  }
  logger.info({ sessionId: req.params.session_id }, 'Session deleted');
  res.json({ session_id: req.params.session_id, status: 'deleted' });
});

// DELETE /v1/memory/:session_id/:memory_id — delete single memory
router.delete('/:session_id/:memory_id', (req: Request, res: Response) => {
  const deleted = store.deleteMemory(req.params.session_id, req.params.memory_id);
  if (!deleted) {
    res.status(404).json({ error: 'Memory not found' });
    return;
  }
  res.json({ memory_id: req.params.memory_id, status: 'deleted' });
});

export default router;
ENDMEMORY

cat > src/routes/sessions.ts << 'ENDSESSIONS'
import { Router, Request, Response } from 'express';
import { store } from '../store';

const router = Router();

router.get('/', (_req: Request, res: Response) => {
  const sessions = store.listSessions();
  res.json({ sessions, count: sessions.length });
});

export default router;
ENDSESSIONS

cat > src/routes/docs.ts << 'ENDDOCS'
import { Router, Request, Response } from 'express';
const router = Router();

router.get('/', (_req: Request, res: Response) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Agent Memory API</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 860px; margin: 40px auto; padding: 0 20px; background: #0f0f0f; color: #e0e0e0; }
    h1 { color: #7c3aed; } h2 { color: #a78bfa; border-bottom: 1px solid #333; padding-bottom: 8px; }
    pre { background: #1a1a1a; padding: 16px; border-radius: 8px; overflow-x: auto; font-size: 13px; }
    code { color: #c084fc; }
    .badge { display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 12px; margin-right: 8px; color: white; }
    .get { background: #065f46; } .post { background: #7c3aed; } .delete { background: #991b1b; }
    table { width: 100%; border-collapse: collapse; } td, th { padding: 8px 12px; border: 1px solid #333; text-align: left; }
    th { background: #1a1a1a; }
  </style>
</head>
<body>
  <h1>Agent Memory API</h1>
  <p>Persistent memory and context storage for AI agents — store, retrieve and search memories by session.</p>
  <h2>Endpoints</h2>
  <table>
    <tr><th>Method</th><th>Path</th><th>Description</th></tr>
    <tr><td><span class="badge post">POST</span></td><td>/v1/memory/:session_id</td><td>Add a memory to a session</td></tr>
    <tr><td><span class="badge post">POST</span></td><td>/v1/memory/:session_id/batch</td><td>Add multiple memories</td></tr>
    <tr><td><span class="badge get">GET</span></td><td>/v1/memory/:session_id</td><td>Retrieve session memories</td></tr>
    <tr><td><span class="badge post">POST</span></td><td>/v1/memory/search</td><td>Search memories by query</td></tr>
    <tr><td><span class="badge get">GET</span></td><td>/v1/memory/:session_id/session</td><td>Get session info</td></tr>
    <tr><td><span class="badge delete">DELETE</span></td><td>/v1/memory/:session_id</td><td>Clear session</td></tr>
    <tr><td><span class="badge delete">DELETE</span></td><td>/v1/memory/:session_id/:memory_id</td><td>Delete single memory</td></tr>
    <tr><td><span class="badge get">GET</span></td><td>/v1/sessions</td><td>List all sessions</td></tr>
    <tr><td><span class="badge get">GET</span></td><td>/v1/health</td><td>Health check</td></tr>
  </table>
  <h2>Add Memory</h2>
  <pre>POST /v1/memory/my-session-123
{
  "content": "User prefers concise responses and is based in San Francisco",
  "role": "system",
  "tags": ["preference", "location"]
}</pre>
  <h2>Search Memories</h2>
  <pre>POST /v1/memory/search
{
  "session_id": "my-session-123",
  "query": "user location preference",
  "limit": 5
}</pre>
  <p><a href="/openapi.json" style="color:#a78bfa">OpenAPI JSON</a></p>
</body>
</html>`);
});

export default router;
ENDDOCS

cat > src/routes/openapi.ts << 'ENDOPENAPI'
import { Router, Request, Response } from 'express';
const router = Router();

router.get('/', (_req: Request, res: Response) => {
  res.json({
    openapi: '3.0.0',
    info: {
      title: 'Agent Memory API',
      version: '1.0.0',
      description: 'Persistent memory and context storage for AI agents — store, retrieve and search memories by session.',
    },
    servers: [{ url: 'https://agent-memory-api.onrender.com' }],
    paths: {
      '/v1/memory/{session_id}': {
        post: { summary: 'Add memory to session', responses: { '201': { description: 'Memory added' } } },
        get: { summary: 'Retrieve session memories', responses: { '200': { description: 'Memory list' } } },
        delete: { summary: 'Clear session', responses: { '200': { description: 'Session deleted' } } },
      },
      '/v1/memory/{session_id}/batch': {
        post: { summary: 'Add multiple memories', responses: { '201': { description: 'Memories added' } } },
      },
      '/v1/memory/search': {
        post: { summary: 'Search memories by query', responses: { '200': { description: 'Search results' } } },
      },
      '/v1/sessions': {
        get: { summary: 'List all sessions', responses: { '200': { description: 'Session list' } } },
      },
      '/v1/health': {
        get: { summary: 'Health check', responses: { '200': { description: 'OK' } } },
      },
    },
  });
});

export default router;
ENDOPENAPI

cat > src/index.ts << 'ENDINDEX'
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { logger } from './logger';
import memoryRouter from './routes/memory';
import sessionsRouter from './routes/sessions';
import docsRouter from './routes/docs';
import openapiRouter from './routes/openapi';
import { store } from './store';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(rateLimit({ windowMs: 60_000, max: 120, standardHeaders: true, legacyHeaders: false }));

app.get('/', (_req, res) => {
  res.json({
    service: 'agent-memory-api',
    version: '1.0.0',
    description: 'Persistent memory and context storage for AI agents.',
    status: 'ok',
    docs: '/docs',
    health: '/v1/health',
    stats: {
      total_sessions: store.totalSessions(),
      total_memories: store.totalMemories(),
    },
    endpoints: {
      add_memory: 'POST /v1/memory/:session_id',
      batch_add: 'POST /v1/memory/:session_id/batch',
      get_memories: 'GET /v1/memory/:session_id',
      search: 'POST /v1/memory/search',
      clear_session: 'DELETE /v1/memory/:session_id',
      list_sessions: 'GET /v1/sessions',
    },
  });
});

app.get('/v1/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'agent-memory-api',
    total_sessions: store.totalSessions(),
    total_memories: store.totalMemories(),
    timestamp: new Date().toISOString(),
  });
});

app.use('/v1/memory', memoryRouter);
app.use('/v1/sessions', sessionsRouter);
app.use('/docs', docsRouter);
app.use('/openapi.json', openapiRouter);

app.use((req, res) => {
  res.status(404).json({ error: 'Not found', path: req.path });
});

app.listen(PORT, () => {
  logger.info({ port: PORT }, 'Agent Memory API running');
});
ENDINDEX

echo "✅ All files created!"
echo "Next: npm install && npm run dev"