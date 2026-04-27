-- name: InsertJob :exec
INSERT INTO jobs (
  id,
  request_id,
  periodic_job_id,
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
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15);
