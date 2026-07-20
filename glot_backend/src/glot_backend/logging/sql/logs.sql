-- name: InsertApiLog :exec
INSERT INTO api_log (id, request_id, created_at, action, body_bytes, duration_ns, ip, user_agent, info, warnings, debug, error, effects)
SELECT
  id,
  request_id,
  created_at,
  action,
  body_bytes,
  duration_ns,
  ip,
  user_agent,
  info,
  warnings,
  debug,
  error,
  effects
FROM jsonb_to_recordset(@entries::JSONB) AS rows(
  id UUID,
  request_id UUID,
  created_at TIMESTAMPTZ,
  action TEXT,
  body_bytes BIGINT,
  duration_ns BIGINT,
  ip TEXT,
  user_agent TEXT,
  info JSONB,
  warnings JSONB,
  debug JSONB,
  error JSONB,
  effects JSONB
);

-- name: InsertPageLog :exec
INSERT INTO page_log (id, request_id, created_at, route, path, status_code, render_mode, duration_ns, ip, user_agent, referrer, info, warnings, debug, error, effects)
SELECT
  id,
  request_id,
  created_at,
  route,
  path,
  status_code,
  render_mode,
  duration_ns,
  ip,
  user_agent,
  referrer,
  info,
  warnings,
  debug,
  error,
  effects
FROM jsonb_to_recordset(@entries::JSONB) AS rows(
  id UUID,
  request_id UUID,
  created_at TIMESTAMPTZ,
  route TEXT,
  path TEXT,
  status_code INT,
  render_mode TEXT,
  duration_ns BIGINT,
  ip TEXT,
  user_agent TEXT,
  referrer TEXT,
  info JSONB,
  warnings JSONB,
  debug JSONB,
  error JSONB,
  effects JSONB
);

-- name: InsertPageviewLog :exec
INSERT INTO pageview_log (
  id,
  created_at,
  session_id,
  user_id,
  route,
  path,
  user_agent,
  ip
)
SELECT
  id,
  created_at,
  session_id,
  user_id,
  route,
  path,
  user_agent,
  ip
FROM jsonb_to_recordset(@entries::JSONB) AS rows(
  id UUID,
  created_at TIMESTAMPTZ,
  session_id UUID,
  user_id UUID,
  route TEXT,
  path TEXT,
  user_agent TEXT,
  ip TEXT
)
ON CONFLICT (id) DO NOTHING;

-- name: InsertRunLog :exec
INSERT INTO run_log (
  id,
  request_id,
  created_at,
  session_id,
  user_id,
  language,
  outcome,
  duration_ns,
  failure_message
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);

-- name: DeleteApiLogBefore :exec
DELETE FROM api_log
WHERE created_at < $1;

-- name: DeletePageLogBefore :exec
DELETE FROM page_log
WHERE created_at < $1;

-- name: DeletePageviewLogBefore :exec
DELETE FROM pageview_log
WHERE created_at < $1;

-- name: DeleteRunLogBefore :exec
DELETE FROM run_log
WHERE created_at < $1;
