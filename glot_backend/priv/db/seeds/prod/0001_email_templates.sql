INSERT INTO email_templates (
  name,
  subject_template,
  text_body_template,
  html_body_template,
  updated_at
)
VALUES
  (
    'login_token',
    'Your login token',
    'Your login token is: {{token}}',
    NULL,
    NOW()
  ),
  (
    'account_deleted',
    'Your account has been deleted',
    'Your account has been deleted.',
    NULL,
    NOW()
  )
ON CONFLICT (name) DO UPDATE SET
  subject_template = EXCLUDED.subject_template,
  text_body_template = EXCLUDED.text_body_template,
  html_body_template = EXCLUDED.html_body_template,
  updated_at = EXCLUDED.updated_at;
