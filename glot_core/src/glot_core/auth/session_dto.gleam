import gleam/dynamic/decode
import gleam/json
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/session_model
import glot_core/auth/user_dto
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import youid/uuid

pub type SessionResponse {
  SessionResponse(id: uuid.Uuid, user: user_dto.UserResponse, created_at: Timestamp)
}

pub fn from_session(session: session_model.HydratedSession) -> SessionResponse {
  SessionResponse(
    id: session.id,
    user: user_dto.from_hydrated_user(session.user),
    created_at: session.created_at,
  )
}

pub fn encode(response: SessionResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(response.id))),
    #("user", user_dto.encode(response.user)),
    #("createdAt", timestamp_helpers.encode(response.created_at)),
  ])
}

pub fn decoder() -> decode.Decoder(SessionResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use user <- decode.field("user", user_dto.user_decoder())
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())

  decode.success(SessionResponse(id: id, user: user, created_at: created_at))
}
