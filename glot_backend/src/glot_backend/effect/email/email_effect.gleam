import glot_backend/effect/email/email
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_core/email/email_model

pub fn send_email(
  message: email_model.Email,
) -> program_types.Program(Result(Nil, error.SendEmailError)) {
  program_types.Impure(
    program_types.EmailEffect(email.SendEmail(message, program_types.Pure)),
  )
}
