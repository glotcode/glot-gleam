-- name: CountUserActionsByIp :many
WITH windows AS (
  SELECT
    (w->>'unit')::text AS unit,
    (w->>'cutoff')::timestamptz AS cutoff
  FROM jsonb_array_elements(@windows::jsonb) AS w
)
SELECT
  w.unit,
  COUNT(a.*) AS count
FROM windows w
LEFT JOIN user_actions a
  ON a.ip = @ip
 AND a.action = @action
 AND a.created_at >= w.cutoff
GROUP BY w.unit;

-- name: CountUserActionsByUser :many
WITH windows AS (
  SELECT
    (w->>'unit')::text AS unit,
    (w->>'cutoff')::timestamptz AS cutoff
  FROM jsonb_array_elements(@windows::jsonb) AS w
)
SELECT
  w.unit,
  COUNT(a.*) AS count
FROM windows w
LEFT JOIN user_actions a
  ON a.user_id = @user_id
 AND a.action = @action
 AND a.created_at >= w.cutoff
GROUP BY w.unit;

-- name: InsertUserAction :exec
INSERT INTO user_actions (id, request_id, action, ip, user_id, created_at) VALUES ($1, $2, $3, $4, $5, $6);

-- name: DeleteUserActionsBefore :exec
DELETE FROM user_actions
WHERE created_at < $1;
