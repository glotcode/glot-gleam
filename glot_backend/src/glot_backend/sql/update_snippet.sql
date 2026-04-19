-- name: UpdateSnippet :exec
UPDATE snippets SET slug = $1, user_id = $2, language = $3, title = $4, visibility = $5, stdin = $6, run_instructions = $7, files = $8, created_at = $9, updated_at = $10 WHERE id = $11;
