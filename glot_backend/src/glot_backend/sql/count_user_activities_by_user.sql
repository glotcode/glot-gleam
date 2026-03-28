-- name: CountUserActivitiesByUser :one
SELECT COUNT(*) as count FROM user_activities WHERE created_at >= $1 and user_id = $2 AND action = $3;