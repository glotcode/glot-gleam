import gleam/dynamic/decode
import gleam/http/response as http_response
import gleam/json
import gleam/option
import gleam/result
import glot_core/admin_action.{type AdminAction}
import glot_core/api_error_dto
import glot_core/public_action.{type PublicAction}
import glot_frontend/api/response
import lustre/effect.{type Effect}
import rsvp

const endpoint = "/api/mux"

pub fn send_public(
  action action: PublicAction,
  data data: request,
  encode encode_data: fn(request) -> json.Json,
  decode decode_data: decode.Decoder(payload),
  then to_msg: fn(response.Response(payload)) -> msg,
) -> Effect(msg) {
  send(public_action.encode(action), data, encode_data, decode_data, to_msg)
}

pub fn send_admin(
  action action: AdminAction,
  data data: request,
  encode encode_data: fn(request) -> json.Json,
  decode decode_data: decode.Decoder(payload),
  then to_msg: fn(response.Response(payload)) -> msg,
) -> Effect(msg) {
  send(admin_action.encode(action), data, encode_data, decode_data, to_msg)
}

fn send(
  action: json.Json,
  data: request,
  encode_data: fn(request) -> json.Json,
  decode_data: decode.Decoder(payload),
  to_msg: fn(response.Response(payload)) -> msg,
) -> Effect(msg) {
  let body =
    json.object([
      #("action", action),
      #("data", encode_data(data)),
    ])
  let handler =
    rsvp.expect_any_response(fn(result) {
      case result {
        Ok(received) ->
          case decode_response(received, decode_data) {
            Ok(decoded) -> to_msg(decoded)
            Error(error) -> to_msg(response.HttpFailure(error))
          }
        Error(error) -> to_msg(response.HttpFailure(error))
      }
    })

  rsvp.post(endpoint, body, handler)
}

pub fn decode_response(
  received: http_response.Response(String),
  data_decoder: decode.Decoder(a),
) -> Result(response.Response(a), rsvp.Error(String)) {
  use _ <- result.try(ensure_json_response(received))

  case received.status {
    status if status >= 200 && status < 300 ->
      json.parse(received.body, success_decoder(data_decoder))
      |> result.map_error(rsvp.JsonError)
    status if status >= 400 && status < 600 ->
      json.parse(received.body, error_decoder())
      |> result.map_error(rsvp.JsonError)
    _ -> Error(rsvp.UnhandledResponse(received))
  }
}

fn success_decoder(
  data_decoder: decode.Decoder(a),
) -> decode.Decoder(response.Response(a)) {
  use data <- decode.field("data", data_decoder)
  decode.success(response.Success(data))
}

fn error_decoder() -> decode.Decoder(response.Response(a)) {
  api_error_dto.decoder()
  |> decode.map(fn(error) {
    response.ApiFailure(response.Error(
      code: error.code,
      message: error.message,
      request_id: error.request_id,
    ))
  })
}

fn ensure_json_response(
  received: http_response.Response(String),
) -> Result(Nil, rsvp.Error(String)) {
  case http_response.get_header(received, "content-type") {
    Ok("application/json") -> Ok(Nil)
    Ok("application/json;" <> _) -> Ok(Nil)
    _ -> Error(rsvp.UnhandledResponse(received))
  }
}

pub fn nil_decoder() -> decode.Decoder(Nil) {
  decode.then(decode.optional(decode.bool), fn(value) {
    case value {
      option.None -> decode.success(Nil)
      option.Some(_) -> decode.failure(Nil, "Nil")
    }
  })
}
