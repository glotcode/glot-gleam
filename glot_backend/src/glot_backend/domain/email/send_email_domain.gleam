import glot_backend/context
import glot_backend/effect/email/email_effect
import glot_backend/effect/error
import glot_backend/effect/error/infra_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/email/email_model

pub fn send_email(
  _ctx: context.Context,
  email: email_model.Email,
) -> program_types.Program(Nil) {
  use send_result <- program.and_then(email_effect.send_email(email))

  case send_result {
    Ok(_) -> program.succeed(Nil)
    Error(_) ->
      program.fail(
        error.infra(infra_error.EmailError(infra_error.EmailDeliveryFailed)),
      )
  }
}

pub fn email_from_json(
  ctx: context.Context,
  json_str: String,
) -> program_types.Program(email_model.Email) {
  program.parse_json(json_str, email_model.decoder(ctx.regexes.is_email))
}
