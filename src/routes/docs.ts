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
