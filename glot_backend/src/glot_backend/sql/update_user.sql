-- name: UpdateUser :exec
UPDATE users
SET
  email = $1,
  username = $2,
  first_login_at = $3,
  last_login_at = $4,
  created_at = $5,
  updated_at = $6
WHERE id = $7;
