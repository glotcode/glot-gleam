-- name: DeleteSessionsByAccountId :exec
DELETE FROM sessions
WHERE user_id IN (
  SELECT id
  FROM users
  WHERE account_id = $1
);
