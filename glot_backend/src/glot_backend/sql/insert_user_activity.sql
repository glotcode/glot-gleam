-- name: InsertUserActivity :exec
INSERT INTO user_activities (id, action, ip, user_id, created_at) VALUES ($1, $2, $3, $4, $5);
