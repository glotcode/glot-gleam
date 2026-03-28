-- name: InsertSession :exec
INSERT INTO sessions (id, user_id, token, ip, user_agent, created_at) VALUES ($1, $2, $3, $4, $5, $6);
