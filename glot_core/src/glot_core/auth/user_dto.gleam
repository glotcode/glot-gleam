import gleam/dynamic/decode
import gleam/json
import gleam/regexp
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/timestamp_helpers
import glot_core/uuid_helpers
import youid/uuid.{type Uuid}

pub type UserResponse {
  UserResponse(
    id: Uuid,
    email: email_address_model.EmailAddress,
    created_at: Timestamp,
  )
}

pub fn encode(user: UserResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("email", email_address_model.encode(user.email)),
    #("createdAt", timestamp_helpers.encode(user.created_at)),
  ])
}

pub fn from_user(user: user_model.User) -> UserResponse {
  UserResponse(
    id: user.id,
    email: user.email,
    created_at: user.created_at,
  )
}

pub fn user_decoder(is_email: regexp.Regexp) -> decode.Decoder(UserResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use email <- decode.field("email", email_address_model.decoder(is_email))
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())

  decode.success(UserResponse(id: id, email: email, created_at: created_at))
}
