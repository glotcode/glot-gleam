import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/domain/shared/admin_authorization_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/email_template/email_template_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/email_template
import glot_core/admin/email_template_dto
import glot_core/api_action

pub fn get_email_template(
  ctx: context.Context,
  request: email_template_dto.GetEmailTemplateRequest,
) -> program_types.Program(email_template_dto.GetEmailTemplateResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use _ <- program.and_then(admin_authorization_domain.require_admin(session))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.GetAdminEmailTemplateAction,
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use name <- program.and_then(
    email_template.from_db_name(request.name)
    |> result.map_error(error.ValidationError)
    |> program.from_result,
  )
  use template <- program.and_then(
    email_template_effect.get_email_template_by_name(name)
    |> program.require(error.NotFoundError(
      "email_template_not_found",
      "Email template not found",
    )),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(
    email_template_dto.GetEmailTemplateResponse(template: to_detail_response(
      template,
    )),
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(email_template_dto.GetEmailTemplateRequest) {
  program.decode_dynamic(data, email_template_dto.get_request_decoder())
}

fn to_detail_response(
  template: email_template.EmailTemplate,
) -> email_template_dto.EmailTemplateDetailResponse {
  email_template_dto.EmailTemplateDetailResponse(
    name: email_template.to_db_name(template.name),
    subject_template: template.subject_template,
    text_body_template: template.text_body_template,
    html_body_template: template.html_body_template,
    supported_tokens: email_template.supported_tokens(template.name),
    updated_at: template.updated_at,
  )
}
