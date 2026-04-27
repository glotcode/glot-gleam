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
