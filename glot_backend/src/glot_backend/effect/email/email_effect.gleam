import glot_backend/effect/email/email_algebra
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_core/email/email_model.{type Email, type SendEmailResult}

pub fn send_email(
  message: Email,
) -> program_types.Program(Result(SendEmailResult, error.Error)) {
  program_types.Impure(
    program_types.EmailEffect(email_algebra.SendEmail(
      message,
      program_types.Pure,
    )),
  )
}
