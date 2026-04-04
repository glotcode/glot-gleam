import gleam/dynamic
import gleam/http/response.{type Response}
import gleam/json
import glot_core/api_action.{type ApiAction}
import glot_core/auth/login_token_dto
import glot_core/email/email_address_model.{type EmailAddress}
import lustre/effect
import rsvp

pub type ApiRequest(a) {
  ApiRequest(action: ApiAction, data: a)
}

pub fn send_login_token(
  email: EmailAddress,
  to_msg: fn(Result(Response(String), rsvp.Error)) -> msg,
) -> effect.Effect(msg) {
  let req =
    ApiRequest(
      api_action.SendLoginTokenAction,
      login_token_dto.LoginTokenRequest(email),
    )

  send_api_request(req, login_token_dto.encode, to_msg)
}

fn send_api_request(
  req: ApiRequest(a),
  encode_data: fn(a) -> json.Json,
  to_msg: fn(Result(Response(String), rsvp.Error)) -> msg,
) -> effect.Effect(msg) {
  let body = encode_api_request(req, encode_data)
  let handler = rsvp.expect_ok_response(to_msg)

  rsvp.post("/api/mux", body, handler)
}

fn encode_api_request(
  req: ApiRequest(a),
  encode_data: fn(a) -> json.Json,
) -> json.Json {
  json.object([
    #("action", api_action.encode(req.action)),
    #("data", encode_data(req.data)),
  ])
}
