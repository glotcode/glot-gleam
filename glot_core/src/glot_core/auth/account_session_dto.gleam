import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/time/timestamp
import glot_core/auth/platform_model
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import youid/uuid

pub type AccountSessionResponse {
  AccountSessionResponse(
    id: uuid.Uuid,
    ip: option.Option(String),
    os_name: option.Option(platform_model.OperatingSystem),
    browser_name: option.Option(platform_model.Browser),
    created_at: timestamp.Timestamp,
    last_activity_at: timestamp.Timestamp,
  )
}

pub type ListAccountSessionsResponse {
  ListAccountSessionsResponse(sessions: List(AccountSessionResponse))
}

pub type DeleteAccountSessionRequest {
  DeleteAccountSessionRequest(id: uuid.Uuid)
}

pub fn delete_account_session_request_decoder() -> decode.Decoder(
  DeleteAccountSessionRequest,
) {
  use id <- decode.field("id", uuid_helpers.decoder())
  decode.success(DeleteAccountSessionRequest(id: id))
}

pub fn encode_delete_account_session_request(
  request: DeleteAccountSessionRequest,
) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(request.id))),
  ])
}

pub fn encode_account_session(response: AccountSessionResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(response.id))),
    #("ip", json.nullable(response.ip, json.string)),
    #(
      "osName",
      json.nullable(response.os_name, platform_model.encode_operating_system),
    ),
    #(
      "browserName",
      json.nullable(response.browser_name, platform_model.encode_browser),
    ),
    #("createdAt", timestamp_helpers.encode(response.created_at)),
    #("lastActivityAt", timestamp_helpers.encode(response.last_activity_at)),
  ])
}

pub fn account_session_decoder() -> decode.Decoder(AccountSessionResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use ip <- decode.field("ip", decode.optional(decode.string))
  use os_name <- decode.field(
    "osName",
    decode.optional(platform_model.operating_system_decoder()),
  )
  use browser_name <- decode.field(
    "browserName",
    decode.optional(platform_model.browser_decoder()),
  )
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use last_activity_at <- decode.field(
    "lastActivityAt",
    timestamp_helpers.decoder(),
  )
  decode.success(AccountSessionResponse(
    id:,
    ip:,
    os_name:,
    browser_name:,
    created_at:,
    last_activity_at:,
  ))
}

pub fn encode_list_account_sessions_response(
  response: ListAccountSessionsResponse,
) -> json.Json {
  json.object([
    #("sessions", json.array(response.sessions, encode_account_session)),
  ])
}

pub fn list_account_sessions_response_decoder() -> decode.Decoder(
  ListAccountSessionsResponse,
) {
  use sessions <- decode.field(
    "sessions",
    decode.list(account_session_decoder()),
  )
  decode.success(ListAccountSessionsResponse(sessions: sessions))
}
