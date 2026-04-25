-- name: DeleteUsersByAccountId :exec
DELETE FROM users
WHERE account_id = $1;
