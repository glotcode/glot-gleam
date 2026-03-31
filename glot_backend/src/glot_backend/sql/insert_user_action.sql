-- name: InsertUserAction :exec
INSERT INTO user_actions (id, request_id, action, ip, user_id, created_at) VALUES ($1, $2, $3, $4, $5, $6);
