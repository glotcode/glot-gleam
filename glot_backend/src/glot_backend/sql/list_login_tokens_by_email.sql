-- name: ListLoginTokensByEmail :many
SELECT id, email, token, created_at, used_at FROM login_tokens WHERE email = $1 ORDER BY created_at DESC LIMIT $2;
