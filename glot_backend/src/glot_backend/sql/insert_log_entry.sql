-- name: InsertLogEntry :exec
INSERT INTO log_entries (id, created_at, action, duration_ns, user_agent, error, data, effects)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8);
