-- name: GetUserByEmail :one
SELECT id, email, username, first_login_at, last_login_at, created_at, updated_at FROM users WHERE email = $1;
