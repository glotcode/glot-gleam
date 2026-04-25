-- name: UpdateAccount :exec
UPDATE accounts
SET account_state = $2,
    account_state_reason = $3,
    account_tier = $4,
    delete_job_id = $5,
    created_at = $6,
    updated_at = $7
WHERE id = $1;
