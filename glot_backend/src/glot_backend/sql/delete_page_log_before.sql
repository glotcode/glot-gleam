-- name: DeletePageLogBefore :exec
DELETE FROM page_log
WHERE created_at < $1;
