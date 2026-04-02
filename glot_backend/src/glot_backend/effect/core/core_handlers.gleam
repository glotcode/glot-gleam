import gleam/time/timestamp.{type Timestamp}
import glot_backend/crypto_helpers
import glot_backend/effect/error
import glot_backend/email_message
import glot_core/uuid_helpers
import youid/uuid.{type Uuid}

pub type CoreHandlers {
  CoreHandlers(
    new_token: fn(Int) -> String,
    system_time: fn() -> Timestamp,
    uuid_v7: fn(Timestamp) -> Uuid,
    send_email: fn(email_message.EmailMessage) ->
      Result(Nil, error.SendEmailError),
  )
}

pub fn new() -> CoreHandlers {
  CoreHandlers(
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
  _message: email_message.EmailMessage,
) -> Result(Nil, error.SendEmailError) {
  Error(error.InternalSendEmailError("send_email not implemented"))
}
