-- name: UpdateJob :exec
UPDATE jobs
SET job_type = $2,
    payload = $3,
    status = $4,
    attempts = $5,
    max_attempts = $6,
    timeout_seconds = $7,
    run_at = $8,
    started_at = $9,
    completed_at = $10,
    last_error = $11,
    created_at = $12,
    updated_at = $13
WHERE id = $1;
