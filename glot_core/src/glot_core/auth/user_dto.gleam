import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import glot_core/auth/user_model
import glot_core/helpers/uuid_helpers
import youid/uuid.{type Uuid}

// Note, don't expose email or other sensitive information here, this is meant for public API responses
pub type UserResponse {
  UserResponse(id: Uuid, username: Option(String))
}

pub fn encode(user: UserResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("username", json.nullable(user.username, json.string)),
  ])
}

pub fn from_user(user: user_model.User) -> UserResponse {
  UserResponse(id: user.id, username: user.username)
}

pub fn user_decoder() -> decode.Decoder(UserResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use username <- decode.field("username", decode.optional(decode.string))

  decode.success(UserResponse(id: id, username: username))
}
