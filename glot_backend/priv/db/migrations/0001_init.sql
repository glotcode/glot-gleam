-- PERIODIC JOBS

CREATE TABLE IF NOT EXISTS periodic_jobs (
  id UUID PRIMARY KEY, -- Periodic job id.
  job_type TEXT NOT NULL UNIQUE, -- Handler discriminator for enqueued jobs.
  payload JSONB NULL, -- Encoded job input reused for each execution.
  interval_seconds INT NOT NULL, -- Scheduler cadence in seconds.
  enabled BOOLEAN NOT NULL DEFAULT TRUE, -- Whether new executions should be enqueued.
  next_run_at TIMESTAMPTZ NOT NULL, -- Next time the scheduler should enqueue a job.
  last_enqueued_at TIMESTAMPTZ NULL, -- Last time a job was enqueued from this periodic definition.
  last_enqueue_error TEXT NULL, -- Last scheduler error when attempting to enqueue.
  created_at TIMESTAMPTZ NOT NULL, -- Inserted at.
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS job_type_policies (
  job_type TEXT PRIMARY KEY, -- Handler discriminator the policy applies to.
  max_attempts INT NOT NULL, -- Retry limit for new jobs of this type.
  timeout_seconds INT NOT NULL, -- Max run time in seconds for new jobs of this type.
  base_backoff_seconds INT NOT NULL, -- Initial retry delay in seconds for new jobs of this type.
  max_backoff_seconds INT NOT NULL, -- Maximum retry delay in seconds for new jobs of this type.
  created_at TIMESTAMPTZ NOT NULL, -- Inserted at.
  updated_at TIMESTAMPTZ NOT NULL
);

-- JOBS

CREATE TABLE IF NOT EXISTS jobs (
  id UUID PRIMARY KEY, -- Job id.
  request_id UUID NULL, -- Originating request id for logging correlation. Has a value if the job was enqueued during request processing.
  periodic_job_id UUID NULL REFERENCES periodic_jobs(id) ON DELETE SET NULL, -- Periodic definition that enqueued this job, if any.
  job_type TEXT NOT NULL, -- Handler discriminator.
  payload JSONB NULL, -- Encoded job input.
  status TEXT NOT NULL, -- Job status.
  attempts INT NOT NULL DEFAULT 0, -- Attempts so far.
  max_attempts INT NOT NULL, -- Retry limit.
  timeout_seconds INT NOT NULL, -- Max run time in seconds.
  base_backoff_seconds INT NOT NULL, -- Initial retry delay in seconds.
  max_backoff_seconds INT NOT NULL, -- Maximum retry delay in seconds.
  run_at TIMESTAMPTZ NOT NULL, -- Eligible to run at.
  started_at TIMESTAMPTZ NULL, -- Started processing at.
  lease_expires_at TIMESTAMPTZ NULL, -- Current processing lease deadline.
  completed_at TIMESTAMPTZ NULL, -- Completed successfully at.
  timed_out_at TIMESTAMPTZ NULL, -- Most recent attempt timeout timestamp.
  last_error TEXT NULL, -- Last failure message.
  created_at TIMESTAMPTZ NOT NULL, -- Inserted at.
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_jobs_status_run_at ON jobs(status, run_at);
CREATE INDEX idx_jobs_periodic_job_id ON jobs(periodic_job_id);
CREATE INDEX idx_jobs_lease_expires_at ON jobs(lease_expires_at);

-- ACCOUNTS

CREATE TABLE IF NOT EXISTS accounts (
  id UUID PRIMARY KEY,
  account_state TEXT NOT NULL,
  account_state_reason TEXT,
  account_tier TEXT NOT NULL,
  delete_job_id UUID NULL REFERENCES jobs(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

-- NOTE TO SELF: if we want to start using accounts for real, add this table
-- CREATE TABLE account_memberships (
--   account_id UUID NOT NULL REFERENCES accounts(id),
--   user_id UUID NOT NULL REFERENCES users(id),
--   role TEXT NOT NULL,
--   created_at TIMESTAMPTZ NOT NULL,
--   PRIMARY KEY (account_id, user_id)
-- );


-- USERS

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  account_id UUID NOT NULL REFERENCES accounts(id),
  email TEXT NOT NULL UNIQUE,
  username TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL,
  last_login_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_users_account_id ON users(account_id);


-- LOGIN TOKENS

CREATE TABLE login_tokens (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL,
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ
);

CREATE INDEX idx_login_tokens_email ON login_tokens(email);
CREATE INDEX idx_login_tokens_used_at ON login_tokens(used_at);


-- SESSIONS

CREATE TABLE sessions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  token TEXT NOT NULL UNIQUE,
  previous_token TEXT NULL,
  previous_token_valid_until TIMESTAMPTZ NULL,
  ip TEXT NULL,
  os_name TEXT NULL,
  browser_name TEXT NULL,
  user_agent TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  token_updated_at TIMESTAMPTZ NOT NULL,
  last_activity_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_created_at ON sessions(created_at);
CREATE INDEX idx_sessions_last_activity_at ON sessions(last_activity_at);
CREATE UNIQUE INDEX idx_sessions_previous_token
  ON sessions(previous_token)
  WHERE previous_token IS NOT NULL;

-- PASSKEYS

CREATE TABLE IF NOT EXISTS passkey_credentials (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  credential_id BYTEA NOT NULL UNIQUE,
  cose_key BYTEA NOT NULL,
  sign_count BIGINT NOT NULL,
  aaguid BYTEA NOT NULL,
  os_name TEXT NULL,
  browser_name TEXT NULL,
  user_agent TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  last_used_at TIMESTAMPTZ NULL
);

CREATE INDEX idx_passkey_credentials_user_id
  ON passkey_credentials(user_id);

CREATE TABLE IF NOT EXISTS passkey_challenges (
  id UUID PRIMARY KEY,
  user_id UUID NULL REFERENCES users(id) ON DELETE CASCADE,
  flow TEXT NOT NULL,
  challenge_state BYTEA NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_passkey_challenges_user_id
  ON passkey_challenges(user_id);

CREATE INDEX idx_passkey_challenges_expires_at
  ON passkey_challenges(expires_at);

-- SNIPPETS

CREATE TABLE IF NOT EXISTS snippets (
  id UUID PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  user_id UUID NOT NULL REFERENCES users(id),
  language TEXT NOT NULL,
  title TEXT NOT NULL,
  visibility TEXT NOT NULL,
  stdin TEXT NOT NULL,
  run_instructions JSONB NULL,
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

-- APP CONFIG

CREATE TABLE IF NOT EXISTS app_config (
  namespace TEXT NOT NULL,
  key TEXT NOT NULL,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (namespace, key)
);

-- EMAIL TEMPLATES

CREATE TABLE IF NOT EXISTS email_templates (
  name TEXT PRIMARY KEY,
  subject_template TEXT NOT NULL,
  text_body_template TEXT NOT NULL,
  html_body_template TEXT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

-- API LOG

CREATE TABLE IF NOT EXISTS api_log (
  id UUID PRIMARY KEY,
  request_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  action TEXT NOT NULL,
  body_bytes BIGINT NOT NULL,
  duration_ns BIGINT NOT NULL,
  ip TEXT NULL,
  user_agent TEXT NULL,
  info JSONB NULL,
  warnings JSONB NULL,
  debug JSONB NULL,
  error JSONB NULL,
  effects JSONB NULL
);

CREATE INDEX idx_api_log_created_at ON api_log(created_at);

-- PAGE LOG

CREATE TABLE IF NOT EXISTS page_log (
  id UUID PRIMARY KEY,
  request_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  route TEXT NOT NULL,
  path TEXT NOT NULL,
  status_code INT NOT NULL,
  render_mode TEXT NOT NULL,
  duration_ns BIGINT NOT NULL,
  ip TEXT NULL,
  user_agent TEXT NULL,
  referrer TEXT NULL,
  info JSONB NULL,
  warnings JSONB NULL,
  debug JSONB NULL,
  error JSONB NULL,
  effects JSONB NULL
);

CREATE INDEX idx_page_log_created_at ON page_log(created_at);

-- PAGEVIEW LOG

CREATE TABLE IF NOT EXISTS pageview_log (
  id UUID PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL,
  session_id UUID NULL,
  user_id UUID NULL,
  route TEXT NOT NULL,
  path TEXT NOT NULL,
  user_agent TEXT NULL,
  ip TEXT NULL
);

CREATE INDEX idx_pageview_log_created_at
  ON pageview_log(created_at);
CREATE INDEX idx_pageview_log_route_created_at
  ON pageview_log(route, created_at);
CREATE INDEX idx_pageview_log_user_id_created_at
  ON pageview_log(user_id, created_at);

-- RUN LOG

CREATE TABLE IF NOT EXISTS run_log (
  id UUID PRIMARY KEY,
  request_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  session_id UUID NULL,
  user_id UUID NULL,
  language TEXT NOT NULL,
  outcome TEXT NOT NULL,
  duration_ns BIGINT NULL,
  failure_message TEXT NULL
);

CREATE INDEX idx_run_log_created_at ON run_log(created_at);
CREATE INDEX idx_run_log_language_created_at ON run_log(language, created_at);
CREATE INDEX idx_run_log_request_id_created_at
  ON run_log(request_id, created_at);
CREATE INDEX idx_run_log_session_id_created_at
  ON run_log(session_id, created_at);
CREATE INDEX idx_run_log_user_id_created_at
  ON run_log(user_id, created_at);
CREATE INDEX idx_run_log_outcome_created_at
  ON run_log(outcome, created_at);

-- ANALYTICS ROLLUPS

CREATE TABLE IF NOT EXISTS metrics_pageview_daily (
  day DATE NOT NULL,
  route TEXT NOT NULL,
  path TEXT NOT NULL,
  views BIGINT NOT NULL,
  unique_sessions BIGINT NOT NULL,
  unique_users BIGINT NOT NULL,
  PRIMARY KEY (day, route, path)
);

CREATE TABLE IF NOT EXISTS metrics_product_event_daily (
  day DATE NOT NULL,
  event_name TEXT NOT NULL,
  event_count BIGINT NOT NULL,
  unique_sessions BIGINT NOT NULL,
  unique_users BIGINT NOT NULL,
  PRIMARY KEY (day, event_name)
);

CREATE TABLE IF NOT EXISTS metrics_run_daily (
  day DATE NOT NULL,
  language TEXT NOT NULL,
  successful_runs BIGINT NOT NULL,
  failed_runs BIGINT NOT NULL,
  unique_sessions BIGINT NOT NULL,
  unique_users BIGINT NOT NULL,
  PRIMARY KEY (day, language)
);

CREATE TABLE IF NOT EXISTS metrics_reliability_daily (
  day DATE NOT NULL,
  surface TEXT NOT NULL,
  name TEXT NOT NULL,
  request_count BIGINT NOT NULL,
  error_count BIGINT NOT NULL,
  avg_duration_ns BIGINT NOT NULL,
  PRIMARY KEY (day, surface, name)
);

CREATE TABLE IF NOT EXISTS metrics_completed_day (
  day DATE PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- JOB LOG

CREATE TABLE IF NOT EXISTS job_log (
  id UUID PRIMARY KEY,
  request_id UUID NULL, -- Originating request id for logging correlation. Has a value if the job was enqueued during request processing.
  job_id UUID NOT NULL,
  job_type TEXT NOT NULL,
  attempt INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  duration_ns BIGINT NOT NULL,
  info JSONB NULL,
  warnings JSONB NULL,
  debug JSONB NULL,
  error JSONB NULL,
  effects JSONB NULL
);

CREATE INDEX idx_job_log_created_at ON job_log(created_at);
CREATE INDEX idx_job_log_job_id ON job_log(job_id);
