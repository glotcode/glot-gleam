-- name: UpdateJob :exec
UPDATE jobs
SET request_id = $2,
    job_type = $3,
    payload = $4,
    status = $5,
    attempts = $6,
    max_attempts = $7,
    timeout_seconds = $8,
    run_at = $9,
    started_at = $10,
    completed_at = $11,
    last_error = $12,
    created_at = $13,
    updated_at = $14
WHERE id = $1;
