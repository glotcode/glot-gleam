-- name: GetJobById :one
SELECT
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
FROM jobs
WHERE id = $1;

-- name: GetNextJob :one
SELECT
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
FROM jobs
WHERE jobs.status = @pending_status
  AND run_at <= @now
  AND started_at IS NULL
ORDER BY run_at ASC, created_at ASC
LIMIT 1
FOR UPDATE SKIP LOCKED;

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

-- name: InsertJobLog :exec
INSERT INTO job_log (id, request_id, job_id, job_type, attempt, created_at, duration_ns, info, warnings, debug, error, effects)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12);

-- name: UpdateJob :exec
UPDATE jobs
SET request_id = $2,
    periodic_job_id = $3,
    job_type = $4,
    payload = $5,
    status = $6,
    attempts = $7,
    max_attempts = $8,
    timeout_seconds = $9,
    run_at = $10,
    started_at = $11,
    completed_at = $12,
    last_error = $13,
    created_at = $14,
    updated_at = $15
WHERE id = $1;

-- name: UpdatePeriodicJob :exec
UPDATE periodic_jobs
SET job_type = $2,
    payload = $3,
    interval_seconds = $4,
    enabled = $5,
    next_run_at = $6,
    last_enqueued_at = $7,
    last_enqueue_error = $8,
    created_at = $9,
    updated_at = $10
WHERE id = $1;

-- name: DeleteJob :exec
DELETE FROM jobs
WHERE id = $1;

-- name: DeleteBefore :exec
DELETE FROM jobs
WHERE completed_at IS NOT NULL
  AND completed_at < @before
  AND status = ANY(sqlc.arg(statuses)::text[]);

-- name: DeleteJobLogBefore :exec
DELETE FROM job_log
WHERE created_at < $1;
