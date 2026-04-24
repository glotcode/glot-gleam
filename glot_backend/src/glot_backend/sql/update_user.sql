-- name: UpdateUser :exec
UPDATE users
SET
  account_id = $1,
  email = $2,
  username = $3,
  role = $4,
  last_login_at = $5,
  created_at = $6,
  updated_at = $7
WHERE id = $8;
