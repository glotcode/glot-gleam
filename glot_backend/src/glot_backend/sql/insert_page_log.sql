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
