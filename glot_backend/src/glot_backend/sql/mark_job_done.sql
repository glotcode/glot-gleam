-- name: MarkJobDone :exec
UPDATE jobs
SET status = 'done',
    completed_at = $2,
    updated_at = $2
WHERE id = $1;
