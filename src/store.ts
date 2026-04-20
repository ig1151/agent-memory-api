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
