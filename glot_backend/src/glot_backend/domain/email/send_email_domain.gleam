import gleam/json
import gleam/string
import glot_backend/context
import glot_backend/effect/email/email_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/email/email_model

pub fn send_email(
  ctx: context.Context,
  payload: String,
) -> program_types.Program(Nil) {
  case json.parse(payload, email_model.decoder(ctx.regexes.is_email)) {
    Ok(message) -> {
      use send_result <- program.and_then(email_effect.send_email(message))

      case send_result {
        Ok(_) -> program.succeed(Nil)
        Error(err) -> program.fail(error.SendEmailError(err))
      }
    }
    Error(errors) -> {
      program.fail(
        error.SendEmailError(error.InternalSendEmailError(
          "Failed to decode email payload" <> string.inspect(errors),
        )),
      )
    }
  }
}
