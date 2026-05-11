-- name: GetEmailTemplateByName :many
SELECT
  name,
  subject_template,
  text_body_template,
  html_body_template,
  updated_at
FROM email_templates
WHERE name = $1;
