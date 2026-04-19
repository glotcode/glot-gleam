-- name: ListSnippetsByUser :many
SELECT id, slug, user_id, language, title, visibility, stdin, run_instructions, created_at, updated_at FROM snippets WHERE user_id = $1;
