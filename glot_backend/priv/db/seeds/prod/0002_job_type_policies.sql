INSERT INTO job_type_policies (
  job_type,
  max_attempts,
  timeout_seconds,
  base_backoff_seconds,
  max_backoff_seconds,
  created_at,
  updated_at
)
VALUES (
  'send_email',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'delete_account',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'clean_api_log',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'clean_page_log',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'clean_pageview_log',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'clean_run_log',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'clean_job_log',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'clean_jobs',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'clean_login_tokens',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'clean_user_actions',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  'aggregate_metrics',
  5,
  120,
  5,
  300,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
)
ON CONFLICT (job_type) DO NOTHING;
