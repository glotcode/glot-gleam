import gleam/dynamic/decode
import gleam/json
import glot_core/helpers/uuid_helpers
import youid/uuid

pub type PageviewRequest {
  PageviewRequest(
    id: uuid.Uuid,
    route: String,
    path: String,
  )
}

pub fn encode(request: PageviewRequest) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(request.id))),
    #("route", json.string(request.route)),
    #("path", json.string(request.path)),
  ])
}

pub fn decoder() -> decode.Decoder(PageviewRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use route <- decode.field("route", decode.string)
  use path <- decode.field("path", decode.string)

  decode.success(PageviewRequest(id:, route:, path:))
}
