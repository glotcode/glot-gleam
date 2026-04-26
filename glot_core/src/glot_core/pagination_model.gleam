import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type CursorPagination {
  CursorPagination(
    after: option.Option(String),
    before: option.Option(String),
    limit: Int,
  )
}

pub fn cursor_decoder() -> decode.Decoder(CursorPagination) {
  use after <- decode.field("after", decode.optional(decode.string))
  use before <- decode.field("before", decode.optional(decode.string))
  use limit <- decode.field("limit", decode.int)
  decode.success(CursorPagination(after:, before:, limit:))
}

pub fn encode_cursor(pagination: CursorPagination) -> json.Json {
  json.object([
    #("after", json.nullable(pagination.after, json.string)),
    #("before", json.nullable(pagination.before, json.string)),
    #("limit", json.int(pagination.limit)),
  ])
}
