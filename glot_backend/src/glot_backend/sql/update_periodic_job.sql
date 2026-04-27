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
