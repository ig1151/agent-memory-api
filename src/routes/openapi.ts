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
