-- name: RescheduleJob :exec
UPDATE jobs
SET status = CASE WHEN attempts >= max_attempts THEN 'failed' ELSE 'pending' END,
    run_at = $2,
    started_at = NULL,
    completed_at = NULL,
    last_error = $3,
    updated_at = $4
WHERE id = $1;
