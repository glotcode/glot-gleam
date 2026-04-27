-- name: DeleteApiLogBefore :exec
DELETE FROM api_log
WHERE created_at < $1;
