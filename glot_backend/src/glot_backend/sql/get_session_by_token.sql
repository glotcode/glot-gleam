-- name: GetSessionByToken :one
SELECT
  sessions.id,
  sessions.token,
  sessions.ip,
  sessions.user_agent,
  sessions.created_at,
  users.id AS user_id,
  users.account_id AS user_account_id,
  users.email AS user_email,
  users.username AS user_username,
  users.role AS user_role,
  accounts.account_state AS user_account_state,
  accounts.account_state_reason AS user_account_state_reason,
  accounts.account_tier AS user_account_tier,
  users.last_login_at AS user_last_login_at,
  users.created_at AS user_created_at,
  users.updated_at AS user_updated_at
FROM sessions
INNER JOIN users ON users.id = sessions.user_id
INNER JOIN accounts ON accounts.id = users.account_id
WHERE sessions.token = $1;
