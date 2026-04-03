import gleam/time/timestamp.{type Timestamp}
import glot_backend/helpers/crypto_helpers
import glot_backend/effect/error
import glot_core/email/email_model
import glot_core/helpers/uuid_helpers
import youid/uuid.{type Uuid}

pub type BasicHandlers {
  BasicHandlers(
    new_token: fn(Int) -> String,
    system_time: fn() -> Timestamp,
    uuid_v7: fn(Timestamp) -> Uuid,
    send_email: fn(email_model.Email) ->
      Result(Nil, error.SendEmailError),
  )
}

pub fn new() -> BasicHandlers {
  BasicHandlers(
    new_token: new_token,
    system_time: system_time,
    uuid_v7: uuid_v7,
    send_email: send_email,
  )
}

pub fn new_token(length: Int) -> String {
  crypto_helpers.new_token(length)
}

pub fn system_time() -> Timestamp {
  timestamp.system_time()
}

pub fn uuid_v7(now: Timestamp) -> Uuid {
  uuid_helpers.v7(now)
}

pub fn send_email(
  _message: email_model.Email,
) -> Result(Nil, error.SendEmailError) {
  Error(error.InternalSendEmailError("send_email not implemented"))
}
