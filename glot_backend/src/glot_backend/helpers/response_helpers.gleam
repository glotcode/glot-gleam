import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string
import wisp
import youid/uuid

pub fn error_body(message: String) -> json.Json {
  json.object([#("message", json.string(message))])
}

pub fn error_body_from_decode_errors(
  errors: List(decode.DecodeError),
) -> json.Json {
  error_body(decode_errors_to_string(errors))
}

fn decode_errors_to_string(errors: List(decode.DecodeError)) -> String {
  errors
  |> list.map(fn(error) { string.inspect(error) })
  |> string.join(", ")
}

pub fn with_request_id(
  response: wisp.Response,
  request_id: uuid.Uuid,
) -> wisp.Response {
  wisp.set_header(response, "X-Request-Id", uuid.to_string(request_id))
}
