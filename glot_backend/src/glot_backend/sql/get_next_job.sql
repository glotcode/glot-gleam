-- name: GetNextJob :one
SELECT
  id,
  job_type,
  payload,
  status,
  attempts,
  max_attempts,
  timeout_seconds,
  run_at,
  started_at,
  completed_at,
  last_error,
  created_at,
  updated_at
FROM jobs
WHERE jobs.status = @pending_status
  AND run_at <= @now
  AND started_at IS NULL
ORDER BY run_at ASC, created_at ASC
LIMIT 1
FOR UPDATE SKIP LOCKED;
