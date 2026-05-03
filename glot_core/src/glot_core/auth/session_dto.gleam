import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import youid/uuid

pub type SessionUserResponse {
  SessionUserResponse(
    id: uuid.Uuid,
    username: String,
    role: user_model.UserRole,
  )
}

pub type SessionResponse {
  SessionResponse(
    id: uuid.Uuid,
    user: SessionUserResponse,
    created_at: Timestamp,
  )
}

pub fn from_session(session: session_model.HydratedSession) -> SessionResponse {
  SessionResponse(
    id: session.identity.id,
    user: SessionUserResponse(
      id: session.user.identity.id,
      username: session.user.identity.username,
      role: session.user.identity.role,
    ),
    created_at: session.identity.created_at,
  )
}

pub fn encode(response: SessionResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(response.id))),
    #("user", encode_session_user(response.user)),
    #("createdAt", timestamp_helpers.encode(response.created_at)),
  ])
}

pub fn decoder() -> decode.Decoder(SessionResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use user <- decode.field("user", session_user_decoder())
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())

  decode.success(SessionResponse(id: id, user: user, created_at: created_at))
}

fn encode_session_user(user: SessionUserResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(user.id))),
    #("username", json.string(user.username)),
    #("role", json.string(user_model.role_to_string(user.role))),
  ])
}

fn session_user_decoder() -> decode.Decoder(SessionUserResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use username <- decode.field("username", decode.string)
  use role <- decode.field("role", user_role_decoder())

  decode.success(SessionUserResponse(id:, username:, role:))
}

fn user_role_decoder() -> decode.Decoder(user_model.UserRole) {
  use value <- decode.then(decode.string)
  case user_model.role_from_string(value) {
    option.Some(role) -> decode.success(role)
    option.None -> decode.failure(user_model.RegularUser, "UserRole")
  }
}
