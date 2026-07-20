-- name: ListSessionsByUserId :many
SELECT
  id,
  user_id,
  token,
  previous_token,
  previous_token_valid_until,
  ip,
  os_name,
  browser_name,
  user_agent,
  created_at,
  token_updated_at,
  last_activity_at
FROM sessions
WHERE user_id = $1
  AND created_at >= $2
  AND last_activity_at >= $3
ORDER BY last_activity_at DESC, created_at DESC;

-- name: GetSessionByToken :one
SELECT
  sessions.id,
  sessions.user_id,
  sessions.token,
  sessions.previous_token,
  sessions.previous_token_valid_until,
  sessions.ip,
  sessions.os_name,
  sessions.browser_name,
  sessions.user_agent,
  sessions.created_at,
  sessions.token_updated_at,
  sessions.last_activity_at,
  users.id AS user_id,
  users.account_id AS user_account_id,
  users.email AS user_email,
  users.username AS user_username,
  users.role AS user_role,
  accounts.account_state AS user_account_state,
  accounts.account_state_reason AS user_account_state_reason,
  accounts.account_tier AS user_account_tier,
  accounts.delete_job_id AS user_account_delete_job_id,
  jobs.run_at AS user_account_delete_scheduled_at,
  users.last_login_at AS user_last_login_at,
  users.created_at AS user_created_at,
  users.updated_at AS user_updated_at
FROM sessions
INNER JOIN users ON users.id = sessions.user_id
INNER JOIN accounts ON accounts.id = users.account_id
LEFT JOIN jobs ON jobs.id = accounts.delete_job_id
WHERE sessions.token = $1;

-- name: GetSessionByTokenForUpdate :one
SELECT
  sessions.id,
  sessions.user_id,
  sessions.token,
  sessions.previous_token,
  sessions.previous_token_valid_until,
  sessions.ip,
  sessions.os_name,
  sessions.browser_name,
  sessions.user_agent,
  sessions.created_at,
  sessions.token_updated_at,
  sessions.last_activity_at
FROM sessions
WHERE sessions.token = $1
FOR UPDATE;

-- name: GetSessionByPreviousToken :one
SELECT
  sessions.id,
  sessions.user_id,
  sessions.token,
  sessions.previous_token,
  sessions.previous_token_valid_until,
  sessions.ip,
  sessions.os_name,
  sessions.browser_name,
  sessions.user_agent,
  sessions.created_at,
  sessions.token_updated_at,
  sessions.last_activity_at,
  users.id AS user_id,
  users.account_id AS user_account_id,
  users.email AS user_email,
  users.username AS user_username,
  users.role AS user_role,
  accounts.account_state AS user_account_state,
  accounts.account_state_reason AS user_account_state_reason,
  accounts.account_tier AS user_account_tier,
  accounts.delete_job_id AS user_account_delete_job_id,
  jobs.run_at AS user_account_delete_scheduled_at,
  users.last_login_at AS user_last_login_at,
  users.created_at AS user_created_at,
  users.updated_at AS user_updated_at
FROM sessions
INNER JOIN users ON users.id = sessions.user_id
INNER JOIN accounts ON accounts.id = users.account_id
LEFT JOIN jobs ON jobs.id = accounts.delete_job_id
WHERE sessions.previous_token = $1;

-- name: GetSessionByPreviousTokenForUpdate :one
SELECT
  sessions.id,
  sessions.user_id,
  sessions.token,
  sessions.previous_token,
  sessions.previous_token_valid_until,
  sessions.ip,
  sessions.os_name,
  sessions.browser_name,
  sessions.user_agent,
  sessions.created_at,
  sessions.token_updated_at,
  sessions.last_activity_at
FROM sessions
WHERE sessions.previous_token = $1
FOR UPDATE;

-- name: InsertSession :exec
INSERT INTO sessions (id, user_id, token, previous_token, previous_token_valid_until, ip, os_name, browser_name, user_agent, created_at, token_updated_at, last_activity_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12);

-- name: UpdateSession :exec
UPDATE sessions
SET user_id = $1,
    token = $2,
    previous_token = $3,
    previous_token_valid_until = $4,
    ip = $5,
    os_name = $6,
    browser_name = $7,
    user_agent = $8,
    created_at = $9,
    token_updated_at = $10,
    last_activity_at = $11
WHERE id = $12;

-- name: DeleteSession :exec
DELETE FROM sessions WHERE id = $1;

-- name: DeleteSessionsByAccountId :exec
DELETE FROM sessions
WHERE user_id IN (
  SELECT id
  FROM users
  WHERE account_id = $1
);

-- name: DeleteExpiredSessions :exec
DELETE FROM sessions
WHERE created_at < $1
   OR last_activity_at < $2;
