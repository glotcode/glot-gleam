import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_core/email/email_address_model
import youid/uuid.{type Uuid}

pub type LoginToken {
  LoginToken(
    id: Uuid,
    email: email_address_model.EmailAddress,
    token: String,
    attempt_count: Int,
    created_at: Timestamp,
    used_at: Option(Timestamp),
  )
}

pub fn set_attempt_count(login_token: LoginToken, count: Int) -> LoginToken {
  LoginToken(..login_token, attempt_count: count)
}

pub fn mark_as_used(login_token: LoginToken, used_at: Timestamp) -> LoginToken {
  LoginToken(..login_token, used_at: option.Some(used_at))
}
