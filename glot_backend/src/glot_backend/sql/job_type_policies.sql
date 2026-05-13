-- name: GetJobTypePolicyByJobType :one
SELECT
  job_type,
  max_attempts,
  timeout_seconds,
  base_backoff_seconds,
  max_backoff_seconds,
  created_at,
  updated_at
FROM job_type_policies
WHERE job_type = $1;
