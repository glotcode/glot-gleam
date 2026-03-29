-- name: GetSessionByToken :one
SELECT
  sessions.id,
  sessions.token,
  sessions.ip,
  sessions.user_agent,
  sessions.created_at,
  users.id AS user_id,
  users.email AS user_email,
  users.created_at AS user_created_at
FROM sessions
INNER JOIN users ON users.id = sessions.user_id
WHERE sessions.token = $1;
