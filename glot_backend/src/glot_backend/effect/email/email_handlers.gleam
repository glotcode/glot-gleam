import glot_backend/effect/error
import glot_core/email/email_model

pub type EmailHandlers {
  EmailHandlers(
    send_email: fn(email_model.Email) -> Result(Nil, error.SendEmailError),
  )
}

pub fn new() -> EmailHandlers {
  EmailHandlers(send_email: send_email)
}

pub fn send_email(
  _message: email_model.Email,
) -> Result(Nil, error.SendEmailError) {
  Error(error.InternalSendEmailError("send_email not implemented"))
}
