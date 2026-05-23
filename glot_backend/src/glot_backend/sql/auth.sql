-- name: GetUserByEmail :one
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
  jobs.run_at AS delete_scheduled_at,
  users.last_login_at,
  users.created_at,
  users.updated_at
FROM users
INNER JOIN accounts ON accounts.id = users.account_id
LEFT JOIN jobs ON jobs.id = accounts.delete_job_id
WHERE users.email = $1;

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
  jobs.run_at AS delete_scheduled_at,
  users.last_login_at,
  users.created_at,
  users.updated_at
FROM users
INNER JOIN accounts ON accounts.id = users.account_id
LEFT JOIN jobs ON jobs.id = accounts.delete_job_id
WHERE users.id = $1;

-- name: ListUsersAfter :many
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
  jobs.run_at AS delete_scheduled_at,
  users.last_login_at,
  users.created_at,
  users.updated_at
FROM users
INNER JOIN accounts ON accounts.id = users.account_id
LEFT JOIN jobs ON jobs.id = accounts.delete_job_id
WHERE (
    sqlc.narg(after_id)::uuid IS NULL
    OR users.id < sqlc.narg(after_id)::uuid
  )
  AND (
    sqlc.narg(email)::text IS NULL
    OR users.email = sqlc.narg(email)::text
  )
  AND (
    sqlc.narg(username)::text IS NULL
    OR users.username = sqlc.narg(username)::text
  )
  AND (
    sqlc.narg(id)::uuid IS NULL
    OR users.id = sqlc.narg(id)::uuid
  )
  AND (
    sqlc.narg(role)::text IS NULL
    OR users.role = sqlc.narg(role)::text
  )
  AND (
    sqlc.narg(account_state)::text IS NULL
    OR accounts.account_state = sqlc.narg(account_state)::text
  )
  AND (
    sqlc.narg(account_tier)::text IS NULL
    OR accounts.account_tier = sqlc.narg(account_tier)::text
  )
ORDER BY users.id DESC
LIMIT sqlc.arg(page_limit);

-- name: ListUsersBefore :many
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
  jobs.run_at AS delete_scheduled_at,
  users.last_login_at,
  users.created_at,
  users.updated_at
FROM users
INNER JOIN accounts ON accounts.id = users.account_id
LEFT JOIN jobs ON jobs.id = accounts.delete_job_id
WHERE (
    sqlc.narg(before_id)::uuid IS NULL
    OR users.id > sqlc.narg(before_id)::uuid
  )
  AND (
    sqlc.narg(email)::text IS NULL
    OR users.email = sqlc.narg(email)::text
  )
  AND (
    sqlc.narg(username)::text IS NULL
    OR users.username = sqlc.narg(username)::text
  )
  AND (
    sqlc.narg(id)::uuid IS NULL
    OR users.id = sqlc.narg(id)::uuid
  )
  AND (
    sqlc.narg(role)::text IS NULL
    OR users.role = sqlc.narg(role)::text
  )
  AND (
    sqlc.narg(account_state)::text IS NULL
    OR accounts.account_state = sqlc.narg(account_state)::text
  )
  AND (
    sqlc.narg(account_tier)::text IS NULL
    OR accounts.account_tier = sqlc.narg(account_tier)::text
  )
ORDER BY users.id ASC
LIMIT sqlc.arg(page_limit);

-- name: ListLoginTokensByEmail :many
SELECT id, email, token, created_at, used_at FROM login_tokens WHERE email = $1 ORDER BY created_at DESC LIMIT $2;

-- name: GetPasskeyCredentialByCredentialId :one
SELECT
  id,
  user_id,
  credential_id,
  cose_key,
  sign_count,
  aaguid,
  os_name,
  browser_name,
  user_agent,
  created_at,
  updated_at,
  last_used_at
FROM passkey_credentials
WHERE credential_id = $1;

-- name: ListPasskeyCredentialsByUserId :many
SELECT
  id,
  user_id,
  credential_id,
  cose_key,
  sign_count,
  aaguid,
  os_name,
  browser_name,
  user_agent,
  created_at,
  updated_at,
  last_used_at
FROM passkey_credentials
WHERE user_id = $1
ORDER BY created_at ASC;

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
  token_updated_at
FROM sessions
WHERE user_id = $1
  AND created_at >= $2
ORDER BY created_at DESC;

-- name: GetPasskeyChallengeById :one
SELECT
  id,
  user_id,
  flow,
  challenge_state,
  created_at,
  expires_at
FROM passkey_challenges
WHERE id = $1;

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
  sessions.token_updated_at
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
  sessions.token_updated_at
FROM sessions
WHERE sessions.previous_token = $1
FOR UPDATE;

-- name: InsertUser :exec
INSERT INTO users (id, account_id, email, username, role, last_login_at, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8);

-- name: InsertAccount :exec
INSERT INTO accounts (id, account_state, account_state_reason, account_tier, delete_job_id, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7);

-- name: InsertLoginToken :exec
INSERT INTO login_tokens (id, email, token, created_at, used_at) VALUES ($1, $2, $3, $4, $5);

-- name: InsertSession :exec
INSERT INTO sessions (id, user_id, token, previous_token, previous_token_valid_until, ip, os_name, browser_name, user_agent, created_at, token_updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);

-- name: InsertPasskeyCredential :exec
INSERT INTO passkey_credentials (id, user_id, credential_id, cose_key, sign_count, aaguid, os_name, browser_name, user_agent, created_at, updated_at, last_used_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12);

-- name: InsertPasskeyChallenge :exec
INSERT INTO passkey_challenges (id, user_id, flow, challenge_state, created_at, expires_at) VALUES ($1, $2, $3, $4, $5, $6);

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
    token_updated_at = $10
WHERE id = $11;

-- name: UpdateAccount :exec
UPDATE accounts
SET account_state = $2,
    account_state_reason = $3,
    account_tier = $4,
    delete_job_id = $5,
    created_at = $6,
    updated_at = $7
WHERE id = $1;

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

-- name: UpdateLoginToken :exec
UPDATE login_tokens SET email = $1, token = $2, created_at = $3, used_at = $4 WHERE id = $5;

-- name: UpdatePasskeyCredential :exec
UPDATE passkey_credentials
SET user_id = $1,
    credential_id = $2,
    cose_key = $3,
    sign_count = $4,
    aaguid = $5,
    os_name = $6,
    browser_name = $7,
    user_agent = $8,
    created_at = $9,
    updated_at = $10,
    last_used_at = $11
WHERE id = $12;

-- name: DeleteSession :exec
DELETE FROM sessions WHERE id = $1;

-- name: DeletePasskeyChallenge :exec
DELETE FROM passkey_challenges
WHERE id = $1;

-- name: DeletePasskeyCredential :exec
DELETE FROM passkey_credentials
WHERE id = $1;

-- name: DeleteSessionsByAccountId :exec
DELETE FROM sessions
WHERE user_id IN (
  SELECT id
  FROM users
  WHERE account_id = $1
);

-- name: DeleteSessionsBefore :exec
DELETE FROM sessions
WHERE created_at < $1;

-- name: DeleteLoginTokensBefore :exec
DELETE FROM login_tokens
WHERE created_at < $1;

-- name: DeleteUsersByAccountId :exec
DELETE FROM users
WHERE account_id = $1;

-- name: DeleteAccount :exec
DELETE FROM accounts
WHERE id = $1;
