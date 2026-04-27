-- name: InsertPeriodicJob :exec
INSERT INTO periodic_jobs (
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
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
