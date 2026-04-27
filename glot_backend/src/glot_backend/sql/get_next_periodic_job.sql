-- name: GetNextPeriodicJob :one
SELECT
  id,
  job_type,
  payload,
  interval_seconds,
  enabled,
  next_run_at,
  last_enqueued_at,
  last_enqueue_error,
  created_at,
  updated_at
FROM periodic_jobs
WHERE enabled = TRUE
  AND next_run_at <= @now
ORDER BY next_run_at ASC, created_at ASC
LIMIT 1
FOR UPDATE SKIP LOCKED;
