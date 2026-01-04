-- name: DeleteSnippet :exec
DELETE FROM snippets WHERE id = $1;