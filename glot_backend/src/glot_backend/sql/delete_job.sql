-- name: DeleteJob :exec
DELETE FROM jobs
WHERE id = $1;
