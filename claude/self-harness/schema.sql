-- self-harness SQLite schema.
-- Dedicated DB, separate from claude-broker's data/broker.sqlite.
-- Applied idempotently (CREATE TABLE/INDEX IF NOT EXISTS) by run.sh on every invocation.

CREATE TABLE IF NOT EXISTS sessions (
  id           TEXT PRIMARY KEY,           -- Claude Code sessionId
  repo         TEXT NOT NULL,              -- e.g. "payroll-api", "ordio-standards"
  project_path TEXT NOT NULL,              -- cwd recorded in the transcript
  started_at   TEXT,                       -- timestamp of the first line, if known
  digested_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS incidents (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL REFERENCES sessions(id),
  repo       TEXT NOT NULL,
  kind       TEXT NOT NULL CHECK (kind IN ('correction', 'error', 'manual_workflow', 'denied_action')),
  surface    TEXT,                         -- skill/subagent/tool name implicated, if any
  summary    TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS proposals (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  created_at     TEXT NOT NULL DEFAULT (datetime('now')),
  -- 'repo_local' = a personal, gitignored addition scoped to one specific Ordio repo
  -- (CLAUDE.local.md, or a new — never already-tracked — file under .claude/skills|agents).
  -- No git branch: never committed, never shared, so `content` holds the full proposed
  -- file body directly and review.sh writes it in place on accept.
  -- 'out_of_scope' = mining found a real recurring pattern but the fix needs something
  -- outside the allowlist (e.g. a lint rule). Recorded for you to act on manually;
  -- branch/target_repo/target_path/content stay NULL for these.
  target_surface TEXT NOT NULL CHECK (target_surface IN ('skill', 'subagent', 'claude_md', 'ordio_standards', 'repo_local', 'out_of_scope')),
  target_repo    TEXT,
  target_path    TEXT,
  branch         TEXT,
  content        TEXT,                     -- full proposed file body, repo_local only
  summary        TEXT NOT NULL,
  incident_ids   TEXT NOT NULL,            -- JSON array, the evidence this proposal is built on
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  feedback       TEXT,                     -- your reason, on reject — fed back into the next mining pass
  decided_at     TEXT
);

CREATE INDEX IF NOT EXISTS idx_incidents_repo ON incidents(repo);
CREATE INDEX IF NOT EXISTS idx_proposals_status ON proposals(status);
