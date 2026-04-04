-- name: GetSnippetBySlug :one
SELECT
  snippets.id,
  snippets.slug,
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
  users.username AS user_username,
  users.first_login_at AS user_first_login_at,
  users.created_at AS user_created_at,
  users.updated_at AS user_updated_at
FROM snippets
INNER JOIN users ON users.id = snippets.user_id
WHERE snippets.slug = $1;
