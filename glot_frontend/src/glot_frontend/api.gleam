import gleam/dynamic/decode
import gleam/json
import gleam/option
import glot_core/api_action.{type ApiAction}
import glot_core/auth/login_dto
import glot_core/auth/login_token_dto
import glot_core/email/email_address_model.{type EmailAddress}
import glot_core/run
import glot_core/snippet/snippet_dto
import lustre/effect
import rsvp

pub type ApiRequest(a) {
  ApiRequest(action: ApiAction, data: a)
}

pub type ApiError {
  ApiError(code: String, message: String)
}

pub type ApiResponse(a) {
  ApiSuccess(data: a)
  ApiFailure(error: ApiError)
  HttpFailure(rsvp.Error)
}

pub fn send_login_token(
  email: EmailAddress,
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req =
    ApiRequest(
      api_action.SendLoginTokenAction,
      login_token_dto.LoginTokenRequest(email),
    )

  send_api_request(req, login_token_dto.encode, nil_decoder(), to_msg)
}

pub fn login(
  email: EmailAddress,
  token: String,
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req =
    ApiRequest(
      api_action.LoginAction,
      login_dto.LoginRequest(email: email, token: token),
    )

  send_api_request(req, login_dto.encode, nil_decoder(), to_msg)
}

pub fn run_code(
  request: run.RunRequest,
  to_msg: fn(ApiResponse(run.RunResult)) -> msg,
) -> effect.Effect(msg) {
  let req = ApiRequest(api_action.RunAction, request)

  send_api_request(req, run.encode_run_request, run.run_result_decoder(), to_msg)
}

pub fn create_snippet(
  request: snippet_dto.CreateSnippetRequest,
  to_msg: fn(ApiResponse(snippet_dto.SnippetResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = ApiRequest(api_action.CreateSnippetAction, request)

  send_api_request(
    req,
    fn(create_request) {
      json.object([
        #("data", snippet_dto.encode_data(create_request.data)),
      ])
    },
    snippet_dto.response_decoder(),
    to_msg,
  )
}

fn send_api_request(
  req: ApiRequest(a),
  encode_data: fn(a) -> json.Json,
  decode_data: decode.Decoder(b),
  to_msg: fn(ApiResponse(b)) -> msg,
) -> effect.Effect(msg) {
  let body = encode_api_request(req, encode_data)
  let handler =
    rsvp.expect_json(api_response_decoder(decode_data), fn(result) {
      case result {
        Ok(response) -> to_msg(response)
        Error(error) -> to_msg(HttpFailure(error))
      }
    })

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

fn api_response_decoder(data_decoder: decode.Decoder(a)) -> decode.Decoder(ApiResponse(a)) {
  use ok <- decode.field("ok", decode.bool)

  case ok {
    True -> {
      use data <- decode.field("data", data_decoder)
      decode.success(ApiSuccess(data))
    }

    False -> {
      use error <- decode.field("error", api_error_decoder())
      decode.success(ApiFailure(error))
    }
  }
}

fn api_error_decoder() -> decode.Decoder(ApiError) {
  use code <- decode.field("code", decode.string)
  use message <- decode.field("message", decode.string)
  decode.success(ApiError(code: code, message: message))
}

fn nil_decoder() -> decode.Decoder(Nil) {
  decode.then(decode.optional(decode.bool), fn(value) {
    case value {
      option.None -> decode.success(Nil)
      option.Some(_) -> decode.failure(Nil, "Nil")
    }
  })
}
