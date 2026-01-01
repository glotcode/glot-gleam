import gleam/dynamic/decode
import gleam/json
import gleam/regexp
import gleam/time/timestamp.{type Timestamp}
import glot_core/email
import glot_core/timestamp_helpers
import glot_core/uuid_helpers
import youid/uuid.{type Uuid}

pub type User {
  User(id: Uuid, email: email.Email, created_at: Timestamp)
}

pub fn encode(user: User) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("email", email.encode(user.email)),
    #("createdAt", timestamp_helpers.encode(user.created_at)),
  ])
}

pub fn user_decoder(is_email: regexp.Regexp) -> decode.Decoder(User) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use email <- decode.field("email", email.decoder(is_email))
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())

  decode.success(User(id: id, email: email, created_at: created_at))
}
