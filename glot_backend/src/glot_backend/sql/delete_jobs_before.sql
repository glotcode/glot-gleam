-- name: DeleteBefore :exec
DELETE FROM jobs
WHERE completed_at IS NOT NULL
  AND completed_at < @before
  AND status = ANY(sqlc.arg(statuses)::text[]);
