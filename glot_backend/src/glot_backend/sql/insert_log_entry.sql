-- name: InsertApiLog :exec
INSERT INTO api_log (id, request_id, created_at, action, body_bytes, duration_ns, ip, user_agent, error, data, effects)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
