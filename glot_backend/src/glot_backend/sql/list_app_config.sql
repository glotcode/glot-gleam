-- name: ListAppConfig :many
SELECT
  namespace,
  key,
  value::text AS value
FROM app_config
ORDER BY namespace ASC, key ASC;
