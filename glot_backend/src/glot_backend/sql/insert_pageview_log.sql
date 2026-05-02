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
