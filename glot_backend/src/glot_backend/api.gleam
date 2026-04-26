import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/option
import gleam/string
import glot_backend/context
import glot_backend/domain/account/cancel_delete_account_domain
import glot_backend/domain/account/get_account_domain
import glot_backend/domain/account/schedule_delete_account_domain
import glot_backend/domain/account/update_account_domain
import glot_backend/domain/auth/get_session_domain
import glot_backend/domain/auth/login_domain
import glot_backend/domain/auth/logout_domain
import glot_backend/domain/auth/send_login_token_domain
import glot_backend/domain/run_code/run_domain
import glot_backend/domain/snippet/create_snippet_domain
import glot_backend/domain/snippet/delete_snippet_domain
import glot_backend/domain/snippet/get_snippet_domain
import glot_backend/domain/snippet/list_public_snippets_domain
import glot_backend/domain/snippet/list_session_snippets_domain
import glot_backend/domain/snippet/update_snippet_domain
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/interpreter
import glot_backend/effect/program
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/server_timing
import glot_backend/worker/log_worker
import glot_core/api_action
import glot_core/auth/account_dto
import glot_core/auth/account_model
import glot_core/auth/session_dto
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
  let effect_runtime = runtime.new(db)

  let #(api_result, state) =
    handle_api_request(ctx, api_request)
    |> interpreter.run(effect_runtime, ctx)

  let total_duration_ns = erlang.perf_counter_ns() - ctx.started_at
  insert_log_entry(
    ctx,
    log_worker_subject,
    state,
    api_request,
    total_duration_ns,
    api_result,
  )
  result_to_response(
    ctx,
    req,
    state.effect_measurements,
    total_duration_ns,
    api_result,
  )
}

fn handle_api_request(
  ctx: context.Context,
  api_request: ApiRequest,
) -> program_types.Program(ApiResult) {
  case api_request.action {
    api_action.RunAction -> {
      use request <- program.and_then(run_domain.request_from_dynamic(
        api_request.data,
      ))
      run_domain.run(ctx, request)
      |> program.map(RunResultResponse)
    }
    api_action.GetSessionAction -> {
      get_session_domain.get_session(ctx)
      |> program.map(SessionResponse)
    }
    api_action.LogoutAction ->
      logout_domain.logout(ctx)
      |> program.map(fn(_) { LogoutResponse })
    api_action.GetAccountAction -> {
      get_account_domain.get_account(ctx)
      |> program.map(AccountResponse)
    }
    api_action.UpdateAccountAction -> {
      use request <- program.and_then(
        update_account_domain.request_from_dynamic(api_request.data),
      )
      update_account_domain.update_account(ctx, request)
      |> program.map(AccountResponse)
    }
    api_action.ScheduleDeleteAccountAction ->
      schedule_delete_account_domain.schedule_delete_account(ctx)
      |> program.map(fn(_) { NoContentResponse })
    api_action.CancelDeleteAccountAction ->
      cancel_delete_account_domain.cancel_delete_account(ctx)
      |> program.map(fn(_) { NoContentResponse })
    api_action.GetSnippetAction -> {
      use request <- program.and_then(get_snippet_domain.request_from_dynamic(
        api_request.data,
      ))
      get_snippet_domain.get_snippet(ctx, request)
      |> program.map(SnippetResponse)
    }
    api_action.ListPublicSnippetsAction -> {
      use request <- program.and_then(
        list_public_snippets_domain.request_from_dynamic(api_request.data),
      )
      list_public_snippets_domain.list_public_snippets(ctx, request)
      |> program.map(SnippetsResponse)
    }
    api_action.ListSessionSnippetsAction -> {
      use request <- program.and_then(
        list_session_snippets_domain.request_from_dynamic(api_request.data),
      )
      list_session_snippets_domain.list_session_snippets(ctx, request)
      |> program.map(SnippetsResponse)
    }
    api_action.CreateSnippetAction -> {
      use request <- program.and_then(
        create_snippet_domain.request_from_dynamic(api_request.data),
      )
      create_snippet_domain.create_snippet(ctx, request)
      |> program.map(SnippetResponse)
    }
    api_action.UpdateSnippetAction -> {
      use request <- program.and_then(
        update_snippet_domain.request_from_dynamic(api_request.data),
      )
      update_snippet_domain.update_snippet(ctx, request)
      |> program.map(SnippetResponse)
    }
    api_action.DeleteSnippetAction -> {
      use request <- program.and_then(
        delete_snippet_domain.request_from_dynamic(api_request.data),
      )
      delete_snippet_domain.delete_snippet(ctx, request)
      |> program.map(fn(_) { NoContentResponse })
    }
    api_action.SendLoginTokenAction -> {
      use request <- program.and_then(
        send_login_token_domain.request_from_dynamic(ctx, api_request.data),
      )
      send_login_token_domain.send_login_token(ctx, request)
      |> program.map(fn(_) { NoContentResponse })
    }
    api_action.LoginAction -> {
      use request <- program.and_then(login_domain.request_from_dynamic(
        ctx,
        api_request.data,
      ))
      login_domain.login(ctx, request)
      |> program.map(LoginResponse)
    }
  }
}

pub type ApiRequest {
  ApiRequest(action: api_action.ApiAction, data: dynamic.Dynamic, bytes: Int)
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
  SessionResponse(option.Option(session_dto.SessionResponse))
  AccountResponse(account_dto.AccountResponse)
  SnippetResponse(snippet_dto.SnippetResponse)
  SnippetsResponse(snippet_dto.ListSnippetsResponse)
  LoginResponse(session_token: String)
  LogoutResponse
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
    SessionResponse(response) ->
      success_response(json.nullable(response, session_dto.encode))
    AccountResponse(response) -> success_response(account_dto.encode(response))
    SnippetResponse(response) ->
      success_response(snippet_dto.encode_response(response))
    SnippetsResponse(response) ->
      success_response(snippet_dto.encode_list_response(response))
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
    LogoutResponse -> {
      success_response(json.null())
      |> wisp.set_cookie(
        request: req,
        name: "session",
        value: "",
        security: wisp.Signed,
        max_age: 0,
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
  total_duration_ns: Int,
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
        log_worker.Insert(prepare_log_entry(
          ctx,
          state,
          api_request,
          total_duration_ns,
          error,
        )),
      )
      Nil
    }
    Error(_) -> wisp.log_error("Log worker unavailable")
  }
}

fn prepare_log_entry(
  ctx: context.Context,
  state: program_state.State,
  api_request: ApiRequest,
  total_duration_ns: Int,
  error: option.Option(error.Error),
) -> log_worker.ApiLogEntry {
  let id = basic_handlers.uuid_v7(ctx.timestamp)

  log_worker.ApiLogEntry(
    id: id,
    request_id: ctx.request_id,
    created_at: ctx.timestamp,
    action: api_request.action,
    body_bytes: api_request.bytes,
    duration_ns: total_duration_ns,
    ip: ctx.client_info.ip,
    user_agent: ctx.client_info.user_agent,
    info: state.info_fields,
    warnings: state.warning_fields,
    debug: state.debug_fields,
    error: error,
    effects: state.effect_measurements,
  )
}

fn result_to_response(
  ctx: context.Context,
  request: wisp.Request,
  effects: List(effect_trace.EffectMeasurement),
  total_duration_ns: Int,
  result: Result(ApiResult, error.Error),
) -> wisp.Response {
  case result {
    Ok(response) ->
      api_result_to_response(ctx, request, response)
      |> wisp.set_header(
        "Server-Timing",
        server_timing.prepare(effects, total_duration_ns),
      )
    Error(err) -> error_to_response(err)
  }
}

fn error_to_response(error: error.Error) -> wisp.Response {
  case error {
    error.JsonParseError(error) ->
      error_response(
        "json_parse_error",
        "Decode error: " <> string.inspect(error),
      )
    error.DecodeError(errors) ->
      error_response("decode_error", "Decode error: " <> string.inspect(errors))
    error.EmailInvalidError(message) -> {
      error_response("email_invalid", "Invalid email: " <> message)
    }
    error.ValidationError(message) -> {
      wisp.log_error("Validation error: " <> message)
      error_response("validation_error", message)
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
    error.AccountStateError(account_state_error) ->
      case account_state_error {
        error.ForbiddenAccountState(
          action: action,
          account_state: account_state,
        ) -> {
          wisp.log_error(
            "Account state error: "
            <> account_model.account_state_to_string(account_state)
            <> " not allowed for "
            <> api_action.to_string(action),
          )
          error_response("account_state_error", "Account state not allowed")
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
