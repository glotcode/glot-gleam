-- name: DeletePageviewLogBefore :exec
DELETE FROM pageview_log
WHERE created_at < $1;
