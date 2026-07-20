-- name: ListEmailTemplates :many
SELECT
  name,
  subject_template,
  text_body_template,
  html_body_template,
  updated_at
FROM email_templates
ORDER BY name ASC;

-- name: GetEmailTemplateByName :many
SELECT
  name,
  subject_template,
  text_body_template,
  html_body_template,
  updated_at
FROM email_templates
WHERE name = $1;

-- name: UpdateEmailTemplate :exec
UPDATE email_templates
SET
  subject_template = $2,
  text_body_template = $3,
  html_body_template = $4,
  updated_at = $5
WHERE name = $1;
