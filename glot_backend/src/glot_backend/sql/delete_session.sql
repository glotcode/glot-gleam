-- name: DeleteSession :exec
DELETE FROM sessions WHERE id = $1;
