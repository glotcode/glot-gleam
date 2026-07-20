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

-- name: InsertUser :exec
INSERT INTO users (id, account_id, email, username, role, last_login_at, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8);

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

-- name: DeleteUsersByAccountId :exec
DELETE FROM users
WHERE account_id = $1;
