-- name: InsertUser :exec
INSERT INTO users (id, email, username, role, account_state, account_state_reason, account_tier, last_login_at, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10);
