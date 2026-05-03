-- name: UpsertAppConfig :exec
INSERT INTO app_config (
  namespace,
  key,
  value,
  version,
  updated_at
)
VALUES (
  @namespace,
  @key,
  @value::jsonb,
  @version,
  @updated_at
)
ON CONFLICT (namespace, key) DO UPDATE SET
  value = EXCLUDED.value,
  version = EXCLUDED.version,
  updated_at = EXCLUDED.updated_at;
