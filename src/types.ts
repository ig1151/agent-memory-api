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
