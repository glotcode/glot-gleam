-- name: DeleteJobLogBefore :exec
DELETE FROM job_log
WHERE created_at < $1;
