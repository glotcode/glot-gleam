-- name: ListLoginTokensByUser :many
SELECT id, user_id, token, created_at, used_at FROM login_tokens WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2;
