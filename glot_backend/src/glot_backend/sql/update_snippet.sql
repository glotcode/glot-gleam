-- name: UpdateSnippet :exec
UPDATE snippets SET user_id = $1, language = $2, title = $3, visibility = $4, stdin = $5, run_command = $6, files = $7, created_at = $8, updated_at = $9 WHERE id = $10;
