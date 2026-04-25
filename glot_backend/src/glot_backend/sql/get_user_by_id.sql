-- name: GetUserById :one
SELECT
  users.id,
  users.account_id,
  users.email,
  users.username,
  users.role,
  accounts.account_state,
  accounts.account_state_reason,
  accounts.account_tier,
  accounts.delete_job_id,
  users.last_login_at,
  users.created_at,
  users.updated_at
FROM users
INNER JOIN accounts ON accounts.id = users.account_id
WHERE users.id = $1;
