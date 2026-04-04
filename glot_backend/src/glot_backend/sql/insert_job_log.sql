-- name: InsertJobLog :exec
INSERT INTO job_log (id, request_id, job_id, job_type, attempt, created_at, duration_ns, info, warnings, debug, error, effects)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12);
