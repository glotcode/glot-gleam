-- name: ListSnippetsAfter :many
SELECT
  snippets.id,
  snippets.slug,
  snippets.language,
  snippets.title,
  snippets.visibility,
  snippets.stdin,
  snippets.run_instructions,
  snippets.files,
  snippets.created_at,
  snippets.updated_at,
  users.id AS user_id,
  users.account_id AS user_account_id,
  users.email AS user_email,
  users.username AS user_username,
  users.role AS user_role,
  users.last_login_at AS user_last_login_at,
  users.created_at AS user_created_at,
  users.updated_at AS user_updated_at
FROM snippets
INNER JOIN users ON users.id = snippets.user_id
WHERE
  (
    cardinality(sqlc.arg(visibilities)::text[]) = 0
    OR snippets.visibility = ANY(sqlc.arg(visibilities)::text[])
  )
  AND NOT users.id = ANY(sqlc.arg(skip_user_ids)::uuid[])
  AND (
    sqlc.narg(after_slug)::text IS NULL
    OR snippets.slug < sqlc.narg(after_slug)::text
  )
ORDER BY snippets.slug DESC
LIMIT sqlc.arg(page_limit);
