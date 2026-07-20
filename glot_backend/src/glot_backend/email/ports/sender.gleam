import glot_backend/email/model/config.{type CloudflareConfig}
import glot_backend/system/effect/error
import glot_core/email/email_model.{type Email, type SendEmailResult}

pub type Sender {
  Sender(
    send: fn(CloudflareConfig, Email, Int) ->
      Result(SendEmailResult, error.Error),
  )
}
