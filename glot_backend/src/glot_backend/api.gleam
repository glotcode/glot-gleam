import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/option
import gleam/string
import glot_backend/context
import glot_backend/domain/auth/login_domain
import glot_backend/domain/auth/send_login_token_domain
import glot_backend/domain/run_code/run_domain
import glot_backend/domain/snippet/create_snippet_domain
import glot_backend/domain/snippet/delete_snippet_domain
import glot_backend/domain/snippet/get_snippet_domain
import glot_backend/domain/snippet/update_snippet_domain
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/interpreter
import glot_backend/effect/program
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/erlang
import glot_backend/log
import glot_backend/log_worker
import glot_core/api_action.{type ApiAction}
import glot_core/run
import glot_core/snippet/snippet_dto
import pog
import wisp

pub fn handle_request(
  db: pog.Connection,
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
  req: wisp.Request,
) -> wisp.Response {
  use api_request <- require_api_request(req)
  let handlers = handlers.new(db)

  let #(api_result, state) =
    handle_api_request(ctx, api_request)
    |> interpreter.run(handlers, option.Some(db), ctx)

  insert_log_entry(ctx, log_worker_subject, state, api_request, api_result)
  result_to_response(ctx, req, api_result)
}

fn handle_api_request(
  ctx: context.Context,
  api_request: ApiRequest,
) -> program_types.Program(ApiResult) {
  case api_request.action {
    api_action.RunAction ->
      run_domain.run(ctx, api_request.data)
      |> program.map(RunResultResponse)
    api_action.GetSnippetAction ->
      get_snippet_domain.get_snippet(ctx, api_request.data)
      |> program.map(SnippetResponse)
    api_action.CreateSnippetAction ->
      create_snippet_domain.create_snippet(ctx, api_request.data)
      |> program.map(fn(_) { NoContentResponse })
    api_action.UpdateSnippetAction ->
      update_snippet_domain.update_snippet(ctx, api_request.data)
      |> program.map(fn(_) { NoContentResponse })
    api_action.DeleteSnippetAction ->
      delete_snippet_domain.delete_snippet(ctx, api_request.data)
      |> program.map(fn(_) { NoContentResponse })
    api_action.SendLoginTokenAction ->
      send_login_token_domain.send_login_token(ctx, api_request.data)
      |> program.map(fn(_) { NoContentResponse })
    api_action.LoginAction ->
      login_domain.login(ctx, api_request.data)
      |> program.map(LoginResponse)
  }
}

pub type ApiRequest {
  ApiRequest(action: ApiAction, data: dynamic.Dynamic, bytes: Int)
}

pub fn api_request_decoder(bytes: Int) -> decode.Decoder(ApiRequest) {
  use action <- decode.field("action", api_action.decoder())
  use data <- decode.field("data", decode.dynamic)
  decode.success(ApiRequest(action:, data:, bytes:))
}

fn require_api_request(
  request: wisp.Request,
  next: fn(ApiRequest) -> wisp.Response,
) -> wisp.Response {
  case wisp.read_body_bits(request) {
    Ok(bits) ->
      case bit_array.to_string(bits) {
        Ok(body) ->
          case
            json.parse(body, api_request_decoder(bit_array.byte_size(bits)))
          {
            Ok(api_request) -> next(api_request)
            Error(decode_errors) ->
              error_response(
                "invalid_api_request",
                "Failed to decode as api request: "
                  <> string.inspect(decode_errors),
              )
          }
        Error(_) ->
          error_response("invalid_utf8", "Request body is not valid UTF-8")
      }
    Error(_) -> error_response("body_read_error", "Failed to read request body")
  }
}

type ApiResult {
  RunResultResponse(run.RunResult)
  SnippetResponse(snippet_dto.SnippetResponse)
  LoginResponse(session_token: String)
  NoContentResponse
}

fn api_result_to_response(
  ctx: context.Context,
  req: wisp.Request,
  result: ApiResult,
) -> wisp.Response {
  case result {
    RunResultResponse(run_result) -> {
      success_response(run.encode_run_result(run_result))
    }
    SnippetResponse(response) ->
      success_response(snippet_dto.encode_response(response))
    LoginResponse(session_token) -> {
      success_response(json.null())
      |> wisp.set_cookie(
        request: req,
        name: "session",
        value: session_token,
        security: wisp.Signed,
        max_age: ctx.config.auth.session_cookie_max_age,
      )
    }
    NoContentResponse -> success_response(json.null())
  }
}

fn success_response(data: json.Json) -> wisp.Response {
  wisp.json_response(
    json.to_string(json.object([#("ok", json.bool(True)), #("data", data)])),
    200,
  )
}

fn error_response(code: String, message: String) -> wisp.Response {
  wisp.json_response(
    json.to_string(
      json.object([
        #("ok", json.bool(False)),
        #(
          "error",
          json.object([
            #("code", json.string(code)),
            #("message", json.string(message)),
          ]),
        ),
      ]),
    ),
    200,
  )
}

fn insert_log_entry(
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
  state: program_state.State,
  api_request: ApiRequest,
  result: Result(ApiResult, error.Error),
) -> Nil {
  let error = case result {
    Ok(_) -> option.None
    Error(err) -> option.Some(err)
  }

  case process.subject_owner(log_worker_subject) {
    Ok(_) -> {
      process.send(
        log_worker_subject,
        log_worker.Insert(save_log_entry(ctx, state, api_request, error)),
      )
      Nil
    }
    Error(_) -> wisp.log_error("Log worker unavailable")
  }
}

fn save_log_entry(
  ctx: context.Context,
  state: program_state.State,
  api_request: ApiRequest,
  error: option.Option(error.Error),
) -> log_worker.LogEntry {
  let id = basic_handlers.uuid_v7(ctx.timestamp)
  let duration_ns = erlang.perf_counter_ns() - ctx.started_at

  log_worker.LogEntry(
    id: id,
    request_id: ctx.request_id,
    created_at: ctx.timestamp,
    action: api_action.to_string(api_request.action),
    body_bytes: api_request.bytes,
    duration_ns: duration_ns,
    ip: ctx.client_info.ip,
    user_agent: ctx.client_info.user_agent,
    info: state.info_fields
      |> non_empty_dict
      |> option.map(log.encode_fields)
      |> option.map(json.to_string),
    warnings: state.warning_fields
      |> non_empty_dict
      |> option.map(log.encode_fields)
      |> option.map(json.to_string),
    error: error
      |> option.map(error_to_json)
      |> option.map(json.to_string),
    effects: state.effect_measurements
      |> non_empty_list
      |> option.map(effect_trace.encode_effect_measurements)
      |> option.map(json.to_string),
  )
}

fn non_empty_dict(d: Dict(k, v)) -> option.Option(Dict(k, v)) {
  case dict.is_empty(d) {
    True -> option.None
    False -> option.Some(d)
  }
}

fn non_empty_list(l: List(a)) -> option.Option(List(a)) {
  case l {
    [] -> option.None
    _ -> option.Some(l)
  }
}

fn error_to_json(err: error.Error) -> json.Json {
  json.object([
    #("message", json.string(error.to_string(err))),
  ])
}

fn result_to_response(
  ctx: context.Context,
  request: wisp.Request,
  result: Result(ApiResult, error.Error),
) -> wisp.Response {
  case result {
    Ok(response) -> api_result_to_response(ctx, request, response)
    Error(err) -> error_to_response(err)
  }
}

fn error_to_response(error: error.Error) -> wisp.Response {
  case error {
    error.DecodeError(errors) ->
      error_response("decode_error", "Decode error: " <> string.inspect(errors))
    error.EmailInvalidError(message) -> {
      error_response("email_invalid", "Invalid email: " <> message)
    }
    error.TooManyRequestsError(count, config) -> {
      error_response(
        "too_many_requests",
        "Too many requests: "
          <> int.to_string(count)
          <> " / "
          <> int.to_string(config.max_requests),
      )
    }
    error.QueryError(error.DbQueryError(message: message)) -> {
      wisp.log_error("Query error: " <> message)
      error_response("query_error", "Failed to query data")
    }
    error.CommandError(error.DbCommandError(message: message)) -> {
      wisp.log_error("Command error: " <> message)
      error_response("command_error", "Failed to run command")
    }
    error.TransactionError(error.DbTransactionError(message: message)) -> {
      wisp.log_error("Transaction error: " <> message)
      error_response("transaction_error", "Transaction failed")
    }
    error.LoginError(login_error) ->
      case login_error {
        error.InvalidTokenError -> {
          wisp.log_error("Login error: invalid token")
          error_response("login_error", "Invalid login token")
        }
        error.TokenUsedError -> {
          wisp.log_error("Login error: token used")
          error_response("login_error", "Login token already used")
        }
        error.TokenExpiredError -> {
          wisp.log_error("Login error: token expired")
          error_response("login_error", "Login token expired")
        }
      }
    error.SendEmailError(send_email_error) ->
      case send_email_error {
        error.PublicSendEmailError(message: message) -> {
          wisp.log_error("Send email error (public): " <> message)
          error_response("send_email_error", message)
        }
        error.InternalSendEmailError(message: message) -> {
          wisp.log_error("Send email error (private): " <> message)
          error_response("send_email_error", "Failed to send email")
        }
      }
    error.SessionError(session_error) ->
      case session_error {
        error.MissingSessionTokenError -> {
          wisp.log_error("Session error: missing session token")
          error_response("session_error", "Missing session token")
        }
        error.SessionNotFoundError -> {
          wisp.log_error("Session error: session not found")
          error_response("session_error", "Session not found")
        }
        error.SessionExpiredError -> {
          wisp.log_error("Session error: session expired")
          error_response("session_error", "Session expired")
        }
      }
    error.ClientInfoError(client_info_error) ->
      case client_info_error {
        error.MissingUserIdAndIpError -> {
          wisp.log_error("Client info error: missing user_id and ip")
          error_response("client_info_error", "Missing user_id and ip")
        }
      }
    error.AuthorizationError(authorization_error) ->
      case authorization_error {
        error.NotOwnerError -> {
          wisp.log_error("Authorization error: not owner")
          error_response("authorization_error", "Not authorized")
        }
      }
    error.RunError(run_request_error) ->
      case run_request_error {
        error.PublicRunRequestError(message: message) -> {
          wisp.log_error("Run request error (public): " <> message)
          error_response("run_error", message)
        }
        error.InternalRunRequestError(message: message) -> {
          wisp.log_error("Run request error (private): " <> message)
          error_response("run_error", "Failed to run code")
        }
      }
  }
}
