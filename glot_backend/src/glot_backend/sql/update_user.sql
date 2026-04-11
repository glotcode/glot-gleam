-- name: UpdateUser :exec
UPDATE users
SET
  email = $1,
  username = $2,
  last_login_at = $3,
  created_at = $4,
  updated_at = $5
WHERE id = $6;
