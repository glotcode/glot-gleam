-- name: UpdateLoginToken :exec
UPDATE login_tokens SET email = $1, token = $2, created_at = $3, used_at = $4 WHERE id = $5;
