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
