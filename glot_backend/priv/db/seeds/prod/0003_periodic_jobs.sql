INSERT INTO periodic_jobs (
  id,
  job_type,
  payload,
  interval_seconds,
  enabled,
  next_run_at,
  last_enqueued_at,
  last_enqueue_error,
  created_at,
  updated_at
)
VALUES (
  uuidv4(),
  'clean_api_log',
  NULL,
  86400,
  TRUE,
  CURRENT_TIMESTAMP,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  uuidv4(),
  'clean_run_log',
  NULL,
  86400,
  TRUE,
  CURRENT_TIMESTAMP,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  uuidv4(),
  'clean_job_log',
  NULL,
  86400,
  TRUE,
  CURRENT_TIMESTAMP,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  uuidv4(),
  'clean_page_log',
  NULL,
  86400,
  TRUE,
  CURRENT_TIMESTAMP,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  uuidv4(),
  'clean_pageview_log',
  NULL,
  86400,
  TRUE,
  CURRENT_TIMESTAMP,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  uuidv4(),
  'aggregate_metrics',
  NULL,
  3600,
  TRUE,
  CURRENT_TIMESTAMP,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  uuidv4(),
  'clean_jobs',
  NULL,
  86400,
  TRUE,
  CURRENT_TIMESTAMP,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  uuidv4(),
  'clean_login_tokens',
  NULL,
  86400,
  TRUE,
  CURRENT_TIMESTAMP,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
), (
  uuidv4(),
  'clean_user_actions',
  NULL,
  86400,
  TRUE,
  CURRENT_TIMESTAMP,
  NULL,
  NULL,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
)
ON CONFLICT (job_type) DO NOTHING;
