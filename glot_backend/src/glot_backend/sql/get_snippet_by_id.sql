-- name: GetSnippetById :one
SELECT
  snippets.id,
  snippets.language,
  snippets.title,
  snippets.visibility,
  snippets.stdin,
  snippets.run_command,
  snippets.files,
  snippets.created_at,
  snippets.updated_at,
  users.id AS user_id,
  users.email AS user_email,
  users.created_at AS user_created_at
FROM snippets
INNER JOIN users ON users.id = snippets.user_id
WHERE snippets.id = $1;
