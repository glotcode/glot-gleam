-- name: ListSnippetsByUser :many
SELECT id, user_id, language, title, visibility, stdin, run_command, created_at, updated_at FROM snippets WHERE user_id = $1;