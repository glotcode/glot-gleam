-- name: GetUserById :one
SELECT id, email, username, last_login_at, created_at, updated_at FROM users WHERE id = $1;
