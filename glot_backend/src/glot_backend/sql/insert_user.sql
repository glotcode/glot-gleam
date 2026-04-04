-- name: InsertUser :exec
INSERT INTO users (id, email, username, first_login_at, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6);
