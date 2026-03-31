-- USERS

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- LOGIN TOKENS

CREATE TABLE login_tokens (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ
);

CREATE INDEX idx_login_tokens_user_id ON login_tokens(user_id);
CREATE INDEX idx_login_tokens_used_at ON login_tokens(used_at);


-- SESSIONS

CREATE TABLE sessions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  token TEXT NOT NULL UNIQUE,
  ip TEXT NULL,
  user_agent TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);

-- SNIPPETS

CREATE TABLE IF NOT EXISTS snippets (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  language TEXT NOT NULL,
  title TEXT NOT NULL,
  visibility TEXT NOT NULL,
  stdin TEXT NOT NULL,
  run_command TEXT NOT NULL,
  files JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_snippets_user_id ON snippets(user_id);
CREATE INDEX idx_snippets_visibility ON snippets(visibility);
CREATE INDEX idx_snippets_language ON snippets(language);

-- USER ACTIVITIES

CREATE TABLE user_actions (
  id UUID PRIMARY KEY,
  request_id UUID NOT NULL,
  action TEXT NOT NULL,
  ip TEXT NULL,
  user_id UUID NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_user_actions_ip ON user_actions(ip);
CREATE INDEX idx_user_actions_user_id ON user_actions(user_id);
CREATE INDEX idx_user_actions_ip_action_created_at
  ON user_actions (ip, action, created_at)
  WHERE ip IS NOT NULL;

CREATE INDEX idx_user_actions_user_action_created_at
  ON user_actions (user_id, action, created_at)
  WHERE user_id IS NOT NULL;

-- LOG ENTRIES

CREATE TABLE IF NOT EXISTS api_log (
  id UUID PRIMARY KEY,
  request_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  action TEXT NOT NULL,
  body_bytes BIGINT NOT NULL,
  duration_ns BIGINT NOT NULL,
  ip TEXT NULL,
  user_agent TEXT NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  error TEXT NULL,
  effects JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE INDEX idx_api_log_created_at ON api_log(created_at);

-- JOBS

CREATE TABLE IF NOT EXISTS jobs (
  id UUID PRIMARY KEY, -- Job id.
  job_type TEXT NOT NULL, -- Handler discriminator.
  payload JSONB NOT NULL, -- Encoded job input.
  status TEXT NOT NULL, -- Job status.
  attempts INT NOT NULL DEFAULT 0, -- Attempts so far.
  max_attempts INT NOT NULL, -- Retry limit.
  timeout_seconds INT NOT NULL, -- Max run time in seconds.
  run_at TIMESTAMPTZ NOT NULL, -- Eligible to run at.
  started_at TIMESTAMPTZ NULL, -- Started processing at.
  completed_at TIMESTAMPTZ NULL, -- Completed successfully at.
  last_error TEXT NULL, -- Last failure message.
  created_at TIMESTAMPTZ NOT NULL, -- Inserted at.
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_jobs_status_run_at ON jobs(status, run_at);
