-- name: GetUserById :one
SELECT id, email, username, role, account_state, account_state_reason, account_tier, last_login_at, created_at, updated_at FROM users WHERE id = $1;
