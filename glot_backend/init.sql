-- USERS

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);


-- LOGIN TOKENS

CREATE TABLE login_tokens (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  token TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL,
  used_at TIMESTAMP
);

CREATE INDEX idx_login_tokens_user_id ON login_tokens(user_id);
CREATE INDEX idx_login_tokens_used_at ON login_tokens(used_at);


-- SESSIONS

CREATE TABLE sessions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  token TEXT NOT NULL UNIQUE,
  ip TEXT NOT NULL,
  user_agent TEXT NOT NULL,
  country TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL
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
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_snippets_user_id ON snippets(user_id);
CREATE INDEX idx_snippets_visibility ON snippets(visibility);
CREATE INDEX idx_snippets_language ON snippets(language);

-- USER ACTIVITIES

create type user_action as enum (
  'send_login_token_action',
  'login_action',
  'run_snippet_action',
  'create_snippet_action',
  'update_snippet_action',
  'delete_snippet_action'
);

CREATE TABLE user_activities (
  id UUID PRIMARY KEY,
  action user_action NOT NULL,
  ip TEXT NOT NULL,
  session_token TEXT NULL,
  created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_user_activities_ip ON user_activities(ip);
CREATE INDEX idx_user_activities_session_token ON user_activities(session_token);
CREATE INDEX idx_user_activities_action ON user_activities(action);
CREATE INDEX idx_user_activities_ts ON user_activities(created_at);