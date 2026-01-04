-- name: InsertUser :exec
INSERT INTO users (id, email, created_at) VALUES ($1, $2, $3);