import { Router, Request, Response } from 'express';
import { store } from '../store';

const router = Router();

router.get('/', (_req: Request, res: Response) => {
  const sessions = store.listSessions();
  res.json({ sessions, count: sessions.length });
});

export default router;
