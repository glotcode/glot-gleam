import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import youid/uuid.{type Uuid}

pub type LoginToken {
  LoginToken(
    id: Uuid,
    user_id: Uuid,
    token: String,
    created_at: Timestamp,
    used_at: Option(Timestamp),
  )
}

pub fn mark_as_used(login_token: LoginToken, used_at: Timestamp) -> LoginToken {
  LoginToken(..login_token, used_at: option.Some(used_at))
}
