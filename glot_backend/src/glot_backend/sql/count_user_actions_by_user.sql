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
