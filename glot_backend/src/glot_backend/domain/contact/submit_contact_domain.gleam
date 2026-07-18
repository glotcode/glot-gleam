import gleam/dict
import gleam/dynamic
import gleam/option
import gleam/result
import gleam/string
import glot_backend/domain/job/job_type_policy_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/email_template/email_template_effect
import glot_backend/effect/error
import glot_backend/effect/error/infra_error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/email_template
import glot_backend/log
import glot_backend/request_context
import glot_core/api_action
import glot_core/auth/session_model
import glot_core/contact_dto
import glot_core/email/email_address_model
import glot_core/email/email_model
import glot_core/job/job_model
import glot_core/public_action
import glot_core/user_action.{type UserAction}
import youid/uuid

pub fn submit_contact(
  request_ctx: request_context.RequestContext,
  request: contact_dto.ContactRequest,
) -> program_types.Program(Nil) {
  use maybe_session <- program.and_then(session_domain.get_session(request_ctx))
  let actor =
    maybe_session
    |> option.map(fn(session) { session.user })
    |> api_action_policy_domain.actor_from_user
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx:,
    action: api_action.public(public_action.SubmitContactAction),
    actor:,
  ))

  case string.trim(request.website) {
    "" -> submit_valid_contact(request_ctx, request, maybe_session, user_action)
    _ -> user_action_effect.create_user_action(user_action)
  }
}

fn submit_valid_contact(
  request_ctx: request_context.RequestContext,
  request: contact_dto.ContactRequest,
  maybe_session: option.Option(session_model.HydratedSession),
  user_action: UserAction,
) -> program_types.Program(Nil) {
  let ctx = request_ctx.context
  use contact <- program.and_then(
    contact_dto.validate(request, ctx.regexes.is_email)
    |> result.map_error(error.validation)
    |> program.from_result,
  )
  use recipient <- program.and_then(contact_recipient(request_ctx))
  use sender <- program.and_then(sender_from_config(request_ctx))
  use template <- program.and_then(contact_template())
  use email <- program.and_then(
    email_template.render_email_template(
      template,
      sender,
      recipient,
      dict.from_list([
        #("email", email_address_model.to_string(contact.email)),
        #("topic", contact_dto.topic_label(contact.topic)),
        #("message", contact.message),
        #("user_id", authenticated_user_id(maybe_session)),
        #("request_id", uuid.to_string(ctx.request_id)),
      ]),
    )
    |> result.map_error(infra_error.EmailTemplateRenderFailed)
    |> email_result,
  )
  use job_id <- program.and_then(basic_effect.uuid_v7())
  use send_email_policy <- program.and_then(
    job_type_policy_domain.require_job_type_policy(job_model.SendEmailJob),
  )
  let send_email_job =
    job_model.send_email_job(
      job_id,
      option.Some(ctx.request_id),
      ctx.timestamp,
      email,
      send_email_policy,
    )

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("job_id", job_id),
        log.string("contact_topic", contact_dto.topic_to_string(contact.topic)),
      ]),
    ),
  )

  transaction_effect.run_all([
    job_effect.create_job_tx(send_email_job),
    user_action_effect.create_user_action_tx(user_action),
  ])
}

fn contact_recipient(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(email_address_model.EmailAddress) {
  let config = dynamic_config.email_config(request_ctx.dynamic_config)
  use raw_address <- program.and_then(
    config.contact_address
    |> option.to_result(infra_error.EmailDeliveryFailed(
      "contact_address_not_configured",
      infra_error.NonRetryable,
    ))
    |> email_result,
  )

  email_address_model.from_string(
    request_ctx.context.regexes.is_email,
    raw_address,
  )
  |> option.to_result(infra_error.EmailDeliveryFailed(
    "invalid_contact_address",
    infra_error.NonRetryable,
  ))
  |> email_result
}

fn sender_from_config(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(email_model.EmailSender) {
  let config = dynamic_config.email_config(request_ctx.dynamic_config)
  use address <- program.and_then(
    email_address_model.from_string(
      request_ctx.context.regexes.is_email,
      config.from_address,
    )
    |> option.to_result(infra_error.EmailDeliveryFailed(
      "invalid_sender_address",
      infra_error.NonRetryable,
    ))
    |> email_result,
  )

  program.succeed(email_model.EmailSender(address:, name: config.from_name))
}

fn contact_template() -> program_types.Program(email_template.EmailTemplate) {
  use maybe_template <- program.and_then(
    email_template_effect.get_email_template_by_name(
      email_template.ContactTemplate,
    ),
  )
  maybe_template
  |> option.to_result(
    infra_error.EmailTemplateMissing(email_template.to_db_name(
      email_template.ContactTemplate,
    )),
  )
  |> email_result
}

fn authenticated_user_id(
  maybe_session: option.Option(session_model.HydratedSession),
) -> String {
  maybe_session
  |> option.map(fn(session) { uuid.to_string(session.user.identity.id) })
  |> option.unwrap("anonymous")
}

fn email_result(
  result: Result(a, infra_error.EmailError),
) -> program_types.Program(a) {
  result
  |> result.map_error(fn(err) { error.infra(infra_error.EmailError(err)) })
  |> program.from_result
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(contact_dto.ContactRequest) {
  program.decode_dynamic(data, contact_dto.decoder())
}
