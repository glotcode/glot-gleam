-- name: GetJobById :one
SELECT
  id,
  request_id,
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
WHERE id = $1;
