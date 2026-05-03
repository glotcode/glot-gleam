-- name: DeleteRunLogBefore :exec
DELETE FROM run_log
WHERE created_at < $1;
