-- name: GetUserById :one
SELECT id, email, username, first_login_at, created_at, updated_at FROM users WHERE id = $1;
