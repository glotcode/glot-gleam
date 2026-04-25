-- name: DeleteSnippetsByAccountId :exec
DELETE FROM snippets
WHERE user_id IN (
  SELECT id
  FROM users
  WHERE account_id = $1
);
