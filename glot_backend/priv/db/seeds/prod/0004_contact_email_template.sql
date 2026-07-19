INSERT INTO email_templates (
  name,
  subject_template,
  text_body_template,
  html_body_template,
  updated_at
)
VALUES (
  'contact',
  'Contact form submission: {{topic}}',
  E'Topic: {{topic}}\nSubmitted email (not verified): {{email}}\nAuthenticated user ID: {{user_id}}\nRequest ID: {{request_id}}\n\n{{message}}',
  NULL,
  NOW()
)
ON CONFLICT (name) DO NOTHING;
