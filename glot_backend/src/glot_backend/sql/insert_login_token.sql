-- name: InsertLoginToken :exec
INSERT INTO login_tokens (id, email, token, created_at, used_at) VALUES ($1, $2, $3, $4, $5);
