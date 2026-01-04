-- name: GetSnippetById :one
SELECT id, user_id, language, title, visibility, stdin, run_command, files, created_at, updated_at FROM snippets WHERE id = $1;