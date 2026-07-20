-- name: InsertAccount :exec
INSERT INTO accounts (id, account_state, account_state_reason, account_tier, delete_job_id, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7);

-- name: UpdateAccount :exec
UPDATE accounts
SET account_state = $2,
    account_state_reason = $3,
    account_tier = $4,
    delete_job_id = $5,
    created_at = $6,
    updated_at = $7
WHERE id = $1;

-- name: DeleteAccount :exec
DELETE FROM accounts
WHERE id = $1;
