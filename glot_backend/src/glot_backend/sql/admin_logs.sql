-- name: ListAdminApiLogsAfter :many
SELECT
  request_id,
  created_at,
  action,
  duration_ns,
  (error IS NOT NULL)::boolean AS has_error
FROM api_log
WHERE (
    NOT @filter_by_request_id::boolean
    OR request_id = @request_id::uuid
  )
  AND (
    NOT @has_errors_only::boolean
    OR api_has_error
  )
  AND (
    NOT @has_after_cursor::boolean
    OR (created_at, request_id) < (@after_created_at::timestamptz, @after_request_id::uuid)
  )
ORDER BY created_at DESC, request_id DESC
LIMIT @page_limit;

-- name: ListAdminApiLogsBefore :many
SELECT
  request_id,
  created_at,
  action,
  duration_ns,
  (error IS NOT NULL)::boolean AS has_error
FROM api_log
WHERE (
    NOT @filter_by_request_id::boolean
    OR request_id = @request_id::uuid
  )
  AND (
    NOT @has_errors_only::boolean
    OR api_has_error
  )
  AND (
    NOT @has_before_cursor::boolean
    OR (created_at, request_id) > (@before_created_at::timestamptz, @before_request_id::uuid)
  )
ORDER BY created_at ASC, request_id ASC
LIMIT @page_limit;

-- name: GetAdminApiLog :one
SELECT
  a.request_id AS request_id,
  a.created_at AS created_at,
  a.action AS action,
  a.body_bytes AS body_bytes,
  a.duration_ns AS duration_ns,
  a.ip AS ip,
  a.user_agent AS user_agent,
  COALESCE(a.info::text, '') AS info,
  COALESCE(a.warnings::text, '') AS warnings,
  COALESCE(a.debug::text, '') AS debug,
  COALESCE(a.error::text, '') AS error,
  COALESCE(a.effects::text, '') AS effects
FROM api_log a
WHERE a.request_id = @request_id::uuid;

-- name: ListAdminJobLogsAfter :many
SELECT
  id,
  request_id,
  job_id,
  job_type,
  attempt,
  created_at,
  duration_ns,
  COALESCE(info::text, '') AS info,
  COALESCE(warnings::text, '') AS warnings,
  COALESCE(debug::text, '') AS debug,
  COALESCE(error::text, '') AS error,
  COALESCE(effects::text, '') AS effects
FROM job_log
WHERE (
    NOT @filter_by_request_id::boolean
    OR request_id = @request_id::uuid
  )
  AND (
    NOT @filter_by_job_id::boolean
    OR job_id = @job_id::uuid
  )
  AND (
    NOT @has_errors_only::boolean
    OR error IS NOT NULL
  )
  AND (
    NOT @has_after_cursor::boolean
    OR (created_at, id) < (@after_created_at::timestamptz, @after_id::uuid)
  )
ORDER BY created_at DESC, id DESC
LIMIT @page_limit;

-- name: ListAdminJobLogsBefore :many
SELECT
  id,
  request_id,
  job_id,
  job_type,
  attempt,
  created_at,
  duration_ns,
  COALESCE(info::text, '') AS info,
  COALESCE(warnings::text, '') AS warnings,
  COALESCE(debug::text, '') AS debug,
  COALESCE(error::text, '') AS error,
  COALESCE(effects::text, '') AS effects
FROM job_log
WHERE (
    NOT @filter_by_request_id::boolean
    OR request_id = @request_id::uuid
  )
  AND (
    NOT @filter_by_job_id::boolean
    OR job_id = @job_id::uuid
  )
  AND (
    NOT @has_errors_only::boolean
    OR error IS NOT NULL
  )
  AND (
    NOT @has_before_cursor::boolean
    OR (created_at, id) > (@before_created_at::timestamptz, @before_id::uuid)
  )
ORDER BY created_at ASC, id ASC
LIMIT @page_limit;

-- name: GetAdminJobLog :one
SELECT
  id,
  request_id,
  job_id,
  job_type,
  attempt,
  created_at,
  duration_ns,
  COALESCE(info::text, '') AS info,
  COALESCE(warnings::text, '') AS warnings,
  COALESCE(debug::text, '') AS debug,
  COALESCE(error::text, '') AS error,
  COALESCE(effects::text, '') AS effects
FROM job_log
WHERE id = @id::uuid;
