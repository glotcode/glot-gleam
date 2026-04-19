-- name: InsertSnippet :exec
INSERT INTO snippets (id, slug, user_id, language, title, visibility, stdin, run_instructions, files, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
