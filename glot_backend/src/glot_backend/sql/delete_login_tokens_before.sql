-- name: DeleteLoginTokensBefore :exec
DELETE FROM login_tokens
WHERE created_at < $1;
