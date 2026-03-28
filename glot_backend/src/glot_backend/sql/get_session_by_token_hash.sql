-- name: GetSessionByToken :one
SELECT id, user_id, token, ip, user_agent, created_at FROM sessions WHERE token = $1;
