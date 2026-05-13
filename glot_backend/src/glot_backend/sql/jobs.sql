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
  base_backoff_seconds,
  max_backoff_seconds,
  run_at,
  started_at,
  lease_expires_at,
  completed_at,
  timed_out_at,
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
  base_backoff_seconds,
  max_backoff_seconds,
  run_at,
  started_at,
  lease_expires_at,
  completed_at,
  timed_out_at,
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

-- name: ListJobsAfter :many
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
  base_backoff_seconds,
  max_backoff_seconds,
  run_at,
  started_at,
  lease_expires_at,
  completed_at,
  timed_out_at,
  last_error,
  created_at,
  updated_at
FROM jobs
WHERE (
    cardinality(sqlc.arg(statuses)::text[]) = 0
    OR status = ANY(sqlc.arg(statuses)::text[])
  )
  AND (
    sqlc.narg(job_type)::text IS NULL
    OR job_type = sqlc.narg(job_type)::text
  )
  AND (
    sqlc.narg(periodic_job_id)::uuid IS NULL
    OR periodic_job_id = sqlc.narg(periodic_job_id)::uuid
  )
  AND (
    sqlc.narg(after_id)::uuid IS NULL
    OR id < sqlc.narg(after_id)::uuid
  )
ORDER BY id DESC
LIMIT sqlc.arg(page_limit);

-- name: ListJobsBefore :many
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
  base_backoff_seconds,
  max_backoff_seconds,
  run_at,
  started_at,
  lease_expires_at,
  completed_at,
  timed_out_at,
  last_error,
  created_at,
  updated_at
FROM jobs
WHERE (
    cardinality(sqlc.arg(statuses)::text[]) = 0
    OR status = ANY(sqlc.arg(statuses)::text[])
  )
  AND (
    sqlc.narg(job_type)::text IS NULL
    OR job_type = sqlc.narg(job_type)::text
  )
  AND (
    sqlc.narg(periodic_job_id)::uuid IS NULL
    OR periodic_job_id = sqlc.narg(periodic_job_id)::uuid
  )
  AND (
    sqlc.narg(before_id)::uuid IS NULL
    OR id > sqlc.narg(before_id)::uuid
  )
ORDER BY id ASC
LIMIT sqlc.arg(page_limit);

-- name: SummarizeJobs :one
SELECT
  COUNT(*)::int AS total_count,
  COUNT(*) FILTER (WHERE status = 'pending')::int AS pending_count,
  COUNT(*) FILTER (WHERE status = 'running')::int AS running_count,
  COUNT(*) FILTER (WHERE status = 'failed')::int AS failed_count,
  COUNT(*) FILTER (WHERE status = 'done')::int AS done_count,
  COUNT(*) FILTER (
    WHERE status = 'pending'
      AND run_at < @now
  )::int AS overdue_count
FROM jobs
WHERE (
    cardinality(sqlc.arg(statuses)::text[]) = 0
    OR status = ANY(sqlc.arg(statuses)::text[])
  )
  AND (
    sqlc.narg(job_type)::text IS NULL
    OR job_type = sqlc.narg(job_type)::text
  )
  AND (
    sqlc.narg(periodic_job_id)::uuid IS NULL
    OR periodic_job_id = sqlc.narg(periodic_job_id)::uuid
  );

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

-- name: ListPeriodicJobs :many
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
ORDER BY job_type ASC;

-- name: GetPeriodicJobById :one
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
WHERE id = $1;

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
  base_backoff_seconds,
  max_backoff_seconds,
  run_at,
  started_at,
  lease_expires_at,
  completed_at,
  timed_out_at,
  last_error,
  created_at,
  updated_at
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19);

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
    base_backoff_seconds = $10,
    max_backoff_seconds = $11,
    run_at = $12,
    started_at = $13,
    lease_expires_at = $14,
    completed_at = $15,
    timed_out_at = $16,
    last_error = $17,
    created_at = $18,
    updated_at = $19
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
