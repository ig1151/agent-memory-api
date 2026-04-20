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
