-- name: DeleteUserActionsBefore :exec
DELETE FROM user_actions
WHERE created_at < $1;
