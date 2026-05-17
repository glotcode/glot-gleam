import glot_backend/effect/error
import glot_backend/effect/error/infra_error
import glot_core/email/email_model
import wisp

pub type EmailHandlers {
  EmailHandlers(send_email: fn(email_model.Email) -> Result(Nil, error.Error))
}

pub fn new() -> EmailHandlers {
  EmailHandlers(send_email: send_email)
}

pub fn send_email(_message: email_model.Email) -> Result(Nil, error.Error) {
  wisp.log_error("send_email not implemented")
  Error(error.infra(infra_error.EmailError(infra_error.EmailDeliveryFailed)))
}
