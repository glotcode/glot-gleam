-- name: GetSessionByToken :one
SELECT id, user_id, token, ip, user_agent, country, created_at FROM sessions WHERE token = $1;