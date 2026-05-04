-- name: ListAppConfig :many
SELECT
  namespace,
  key,
  value::text AS value
FROM app_config
ORDER BY namespace ASC, key ASC;

-- name: UpsertAppConfig :exec
INSERT INTO app_config (
  namespace,
  key,
  value,
  updated_at
)
VALUES (
  @namespace,
  @key,
  @value::jsonb,
  @updated_at
)
ON CONFLICT (namespace, key) DO UPDATE SET
  value = EXCLUDED.value,
  updated_at = EXCLUDED.updated_at;
