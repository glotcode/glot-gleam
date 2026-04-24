-- name: UpdateUser :exec
UPDATE users
SET
  email = $1,
  username = $2,
  role = $3,
  account_state = $4,
  account_state_reason = $5,
  account_tier = $6,
  last_login_at = $7,
  created_at = $8,
  updated_at = $9
WHERE id = $10;
