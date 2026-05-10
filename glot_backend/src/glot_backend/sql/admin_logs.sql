-- name: ListAdminApiLogsAfter :many
SELECT
  id,
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
    OR error IS NOT NULL
  )
  AND (
    NOT @has_after_cursor::boolean
    OR (created_at, id) < (@after_created_at::timestamptz, @after_id::uuid)
  )
ORDER BY created_at DESC, id DESC
LIMIT @page_limit;

-- name: ListAdminApiLogsBefore :many
SELECT
  id,
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
    OR error IS NOT NULL
  )
  AND (
    NOT @has_before_cursor::boolean
    OR (created_at, id) > (@before_created_at::timestamptz, @before_id::uuid)
  )
ORDER BY created_at ASC, id ASC
LIMIT @page_limit;

-- name: GetAdminApiLog :one
SELECT
  a.id AS id,
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
WHERE a.id = @id::uuid;

-- name: ListAdminRunLogsAfter :many
SELECT
  id,
  request_id,
  created_at,
  session_id,
  user_id,
  language,
  outcome,
  duration_ns,
  failure_message
FROM run_log
WHERE (
    NOT @filter_by_request_id::boolean
    OR request_id = @request_id::uuid
  )
  AND (
    NOT @filter_by_session_id::boolean
    OR session_id = @session_id::uuid
  )
  AND (
    NOT @filter_by_user_id::boolean
    OR user_id = @user_id::uuid
  )
  AND (
    NOT @filter_by_language::boolean
    OR language = @language::text
  )
  AND (
    NOT @filter_by_outcome::boolean
    OR outcome = @outcome::text
  )
  AND (
    NOT @has_after_cursor::boolean
    OR (created_at, id) < (@after_created_at::timestamptz, @after_id::uuid)
  )
ORDER BY created_at DESC, id DESC
LIMIT @page_limit;

-- name: ListAdminRunLogsBefore :many
SELECT
  id,
  request_id,
  created_at,
  session_id,
  user_id,
  language,
  outcome,
  duration_ns,
  failure_message
FROM run_log
WHERE (
    NOT @filter_by_request_id::boolean
    OR request_id = @request_id::uuid
  )
  AND (
    NOT @filter_by_session_id::boolean
    OR session_id = @session_id::uuid
  )
  AND (
    NOT @filter_by_user_id::boolean
    OR user_id = @user_id::uuid
  )
  AND (
    NOT @filter_by_language::boolean
    OR language = @language::text
  )
  AND (
    NOT @filter_by_outcome::boolean
    OR outcome = @outcome::text
  )
  AND (
    NOT @has_before_cursor::boolean
    OR (created_at, id) > (@before_created_at::timestamptz, @before_id::uuid)
  )
ORDER BY created_at ASC, id ASC
LIMIT @page_limit;

-- name: GetAdminRunLog :one
SELECT
  id,
  request_id,
  created_at,
  session_id,
  user_id,
  language,
  outcome,
  duration_ns,
  failure_message
FROM run_log
WHERE id = @id::uuid;

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
