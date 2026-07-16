import gleam/dynamic
import gleam/option
import gleam/result
import gleam/string
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/email_template/email_template_effect
import glot_backend/effect/error
import glot_backend/effect/error/resource_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/email_template
import glot_backend/request_context
import glot_core/admin/email_template_dto
import glot_core/admin_action
import glot_core/api_action

pub fn update_email_template(
  request_ctx: request_context.RequestContext,
  request: email_template_dto.UpdateEmailTemplateRequest,
) -> program_types.Program(email_template_dto.UpdateEmailTemplateResponse) {
  let ctx = request_ctx.context

  use session <- program.and_then(session_domain.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.UpdateAdminEmailTemplateAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use name <- program.and_then(
    email_template.from_db_name(request.name)
    |> result.map_error(error.validation)
    |> program.from_result,
  )
  use existing <- program.and_then(
    email_template_effect.get_email_template_by_name(name)
    |> program.require(error.resource(resource_error.EmailTemplateNotFound)),
  )

  let updated_template =
    email_template.EmailTemplate(
      ..existing,
      subject_template: request.subject_template,
      text_body_template: request.text_body_template,
      html_body_template: normalize_html_body_template(
        request.html_body_template,
      ),
      updated_at: ctx.timestamp,
    )

  use _ <- program.and_then(
    email_template.validate_template(updated_template)
    |> result.map_error(error.validation)
    |> program.from_result,
  )
  use _ <- program.and_then(email_template_effect.update_email_template(
    updated_template,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(
    email_template_dto.UpdateEmailTemplateResponse(
      template: email_template_dto.EmailTemplateDetailResponse(
        name: email_template.to_db_name(updated_template.name),
        subject_template: updated_template.subject_template,
        text_body_template: updated_template.text_body_template,
        html_body_template: updated_template.html_body_template,
        supported_tokens: email_template.supported_tokens(updated_template.name),
        updated_at: updated_template.updated_at,
      ),
    ),
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(email_template_dto.UpdateEmailTemplateRequest) {
  program.decode_dynamic(data, email_template_dto.update_request_decoder())
}

fn normalize_html_body_template(
  value: option.Option(String),
) -> option.Option(String) {
  case value {
    option.Some(html) ->
      case string.trim(html) == "" {
        True -> option.None
        False -> option.Some(html)
      }
    option.None -> option.None
  }
}
