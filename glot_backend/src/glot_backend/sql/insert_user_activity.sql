-- name: InsertUserActivity :exec
INSERT INTO user_activities (id, action, ip, session_token, created_at) VALUES ($1, $2, $3, $4, $5);