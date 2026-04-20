import { Router, Request, Response } from "express";
import Joi from "joi";
import { v4 as uuidv4 } from "uuid";
import { store } from "../store";
import { logger } from "../logger";
import { Memory } from "../types";

const router = Router();

const addMemorySchema = Joi.object({
  content: Joi.string().min(1).max(10000).required(),
  role: Joi.string().valid("user", "assistant", "system").default("user"),
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
    role: Joi.string().valid("user", "assistant", "system").default("user"),
    tags: Joi.array().items(Joi.string().max(50)).max(10).optional(),
    metadata: Joi.object().optional(),
  })).min(1).max(50).required(),
});

router.post("/search", (req: Request, res: Response) => {
  const { error, value } = searchSchema.validate(req.body);
  if (error) { res.status(400).json({ error: "Validation failed", details: error.details[0].message }); return; }
  const session = store.getSession(value.session_id);
  const results = store.searchMemories(value.session_id, value.query, value.limit);
  logger.info({ sessionId: value.session_id, query: value.query, results: results.length }, "Memory search complete");
  res.json({ session_id: value.session_id, query: value.query, count: results.length, memories: results });
});

router.post("/:session_id/batch", (req: Request, res: Response) => {
  const { error, value } = batchSchema.validate(req.body);
  if (error) { res.status(400).json({ error: "Validation failed", details: error.details[0].message }); return; }
  const sessionId = req.params.session_id;
  store.getOrCreateSession(sessionId);
  const added: Memory[] = [];
  for (const item of value.memories) {
    const memory: Memory = { id: uuidv4(), session_id: sessionId, content: item.content, role: item.role, tags: item.tags, metadata: item.metadata, created_at: new Date().toISOString() };
    store.addMemory(memory);
    added.push(memory);
  }
  logger.info({ sessionId, count: added.length }, "Batch memories added");
  res.status(201).json({ added: added.length, memories: added });
});

router.post("/:session_id", (req: Request, res: Response) => {
  const { error, value } = addMemorySchema.validate(req.body);
  if (error) { res.status(400).json({ error: "Validation failed", details: error.details[0].message }); return; }
  const sessionId = req.params.session_id;
  store.getOrCreateSession(sessionId);
  const memory: Memory = { id: uuidv4(), session_id: sessionId, content: value.content, role: value.role, tags: value.tags, metadata: value.metadata, created_at: new Date().toISOString() };
  store.addMemory(memory);
  logger.info({ sessionId, memoryId: memory.id, role: memory.role }, "Memory added");
  res.status(201).json(memory);
});

router.get("/:session_id/session", (req: Request, res: Response) => {
  const session = store.getSession(req.params.session_id);
  res.json(session!);
});

router.get("/:session_id", (req: Request, res: Response) => {
  const sessionId = req.params.session_id;
  const session = store.getSession(sessionId);
  const limit = Math.min(parseInt(req.query.limit as string) || 50, 200);
  const role = req.query.role as string | undefined;
  const memories = store.getMemories(sessionId, limit, role);
  res.json({ session_id: sessionId, count: memories.length, total_in_session: session.memory_count, memories });
});

router.delete("/:session_id/:memory_id", (req: Request, res: Response) => {
  const deleted = store.deleteMemory(req.params.session_id, req.params.memory_id);
  res.json({ memory_id: req.params.memory_id, status: "deleted" });
});

router.delete("/:session_id", (req: Request, res: Response) => {
  const deleted = store.deleteSession(req.params.session_id);
  logger.info({ sessionId: req.params.session_id }, "Session deleted");
  res.json({ session_id: req.params.session_id, status: "deleted" });
});

export default router;
