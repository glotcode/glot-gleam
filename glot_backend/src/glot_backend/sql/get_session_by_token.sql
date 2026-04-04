-- name: GetSessionByToken :one
SELECT
  sessions.id,
  sessions.token,
  sessions.ip,
  sessions.user_agent,
  sessions.created_at,
  users.id AS user_id,
  users.email AS user_email,
  users.username AS user_username,
  users.first_login_at AS user_first_login_at,
  users.created_at AS user_created_at,
  users.updated_at AS user_updated_at
FROM sessions
INNER JOIN users ON users.id = sessions.user_id
WHERE sessions.token = $1;
