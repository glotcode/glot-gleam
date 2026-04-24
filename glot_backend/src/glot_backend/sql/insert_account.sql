-- name: InsertAccount :exec
INSERT INTO accounts (id, account_state, account_state_reason, account_tier, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6);
