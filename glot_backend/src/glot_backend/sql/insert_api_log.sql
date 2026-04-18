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
