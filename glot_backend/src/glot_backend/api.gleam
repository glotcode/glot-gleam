import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import glot_backend/api_action.{type ApiAction}
import glot_backend/context
import glot_backend/domain/api/login_domain
import glot_backend/domain/api/run_domain
import glot_backend/domain/api/send_login_token_domain
import glot_backend/domain/api/snippet_create_domain
import glot_backend/effect
import glot_backend/erlang
import glot_backend/log
import glot_backend/log_worker
import glot_backend/effect/handlers as effect_handlers
import glot_core/run
import wisp

pub fn handle_request(
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
  req: wisp.Request,
) -> wisp.Response {
  use api_request <- require_api_request(req)
  let handlers = effect_handlers.from_context(ctx)

  let #(api_result, state) =
    handle_api_request(ctx, api_request)
    |> effect.run(handlers)

  insert_log_entry(ctx, log_worker_subject, state, api_request, api_result)
  result_to_response(ctx, req, api_result)
}

fn handle_api_request(
  ctx: context.Context,
  api_request: ApiRequest,
) -> effect.Program(ApiResult) {
  case api_request.action {
    api_action.RunAction ->
      run_domain.run(ctx, api_request.data)
      |> effect.map(RunResultResponse)
    api_action.SnippetCreateAction ->
      snippet_create_domain.snippet_create(ctx, api_request.data)
      |> effect.map(fn(_) { NoContentResponse })
    api_action.SendLoginTokenAction ->
      send_login_token_domain.send_login_token(ctx, api_request.data)
      |> effect.map(fn(_) { NoContentResponse })
    api_action.LoginAction ->
      login_domain.login(ctx, api_request.data)
      |> effect.map(LoginResponse)
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
  state: effect.State,
  api_request: ApiRequest,
  result: Result(ApiResult, effect.Error),
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
  state: effect.State,
  api_request: ApiRequest,
  error: option.Option(effect.Error),
) -> log_worker.LogEntry {
  let handlers = effect_handlers.from_context(ctx)
  let id = handlers.uuid_v7()
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
      |> option.map(effect_error_to_json)
      |> option.map(json.to_string),
    effects: state.effect_timings
      |> non_empty_list
      |> option.map(encode_effect_timings)
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

fn effect_name_to_string(effect_name: effect.EffectName) -> String {
  case effect_name {
    effect.NewTokenEffect -> "new_token"
    effect.SystemTimeEffect -> "system_time"
    effect.UuidV7Effect -> "uuid_v7"
    effect.LogEffect -> "log"
    effect.PostRunRequestEffect -> "post_run_request"
    effect.SendEmailEffect -> "send_email"
    effect.RunQueryEffect(query_name) -> db_query_name_to_string(query_name)
    effect.RunCommandEffect(command_name) ->
      db_command_name_to_string(command_name)
    effect.RunInTransactionEffect(_) -> "run_in_transaction"
    effect.CustomEffect(name) -> "custom:" <> name
  }
}

fn effect_category(effect_name: effect.EffectName) -> String {
  case effect_name {
    effect.NewTokenEffect -> "util"
    effect.SystemTimeEffect -> "util"
    effect.UuidV7Effect -> "util"
    effect.LogEffect -> "log"
    effect.PostRunRequestEffect -> "docker_run"
    effect.SendEmailEffect -> "email"
    effect.RunQueryEffect(_) -> "db_read"
    effect.RunCommandEffect(_) -> "db_write"
    effect.RunInTransactionEffect(_) -> "db_write"
    effect.CustomEffect(_) -> "custom"
  }
}

fn db_query_name_to_string(query_name: effect.DbQueryName) -> String {
  case query_name {
    effect.DbGetUserByEmailQuery -> "db_get_user_by_email"
    effect.DbListLoginTokensByUserQuery -> "db_list_login_tokens_by_user"
    effect.DbGetSessionByTokenQuery -> "db_get_session_by_token"
    effect.DbGetNextJobQuery -> "db_get_next_job"
    effect.DbCountUserActionsByIpQuery -> "db_count_user_actions_by_ip"
    effect.DbCountUserActionsByUserQuery -> "db_count_user_actions_by_user"
  }
}

fn db_command_name_to_string(command_name: effect.DbCommandName) -> String {
  case command_name {
    effect.DbInsertUserCommand -> "db_insert_user"
    effect.DbInsertJobCommand -> "db_insert_job"
    effect.DbInsertSnippetCommand -> "db_insert_snippet"
    effect.DbInsertSessionCommand -> "db_insert_session"
    effect.DbInsertLoginTokenCommand -> "db_insert_login_token"
    effect.DbUpdateLoginTokenCommand -> "db_update_login_token"
    effect.DbInsertUserActionCommand -> "db_insert_user_action"
    effect.DbMarkJobDoneCommand -> "db_mark_job_done"
    effect.DbRescheduleJobCommand -> "db_reschedule_job"
  }
}

fn encode_effect_timings(effects: List(effect.EffectTiming)) -> json.Json {
  json.object([
    #("effects", json.array(effects, encode_effect_timing)),
    #(
      "summary",
      json.object([
        #("count", json.int(list.length(effects))),
        #(
          "duration_ns",
          json.int(
            list.fold(effects, 0, fn(acc, effect_timing) {
              let #(_, duration_ns) = effect_timing
              acc + duration_ns
            }),
          ),
        ),
      ]),
    ),
  ])
}

fn encode_effect_timing(effect_timing: effect.EffectTiming) -> json.Json {
  let #(effect_name, duration_ns) = effect_timing
  case effect_name {
    effect.RunInTransactionEffect(commands) ->
      json.object([
        #("category", json.string(effect_category(effect_name))),
        #("name", json.string(effect_name_to_string(effect_name))),
        #(
          "commands",
          json.array(list.map(commands, db_command_name_to_string), json.string),
        ),
        #("duration_ns", json.int(duration_ns)),
      ])
    _ ->
      json.object([
        #("category", json.string(effect_category(effect_name))),
        #("name", json.string(effect_name_to_string(effect_name))),
        #("duration_ns", json.int(duration_ns)),
      ])
  }
}

fn effect_error_to_message(err: effect.Error) -> String {
  case err {
    effect.DecodeError(errors) -> "decode_error:" <> string.inspect(errors)
    effect.EmailInvalidError(message) -> "email_invalid:" <> message
    effect.TooManyRequestsError(count, _) ->
      "too_many_requests:" <> int.to_string(count)
    effect.QueryError(effect.DbQueryError(message: message)) ->
      "query_error:" <> message
    effect.CommandError(effect.DbCommandError(message: message)) ->
      "command_error:" <> message
    effect.TransactionError(effect.DbTransactionError(message: message)) ->
      "transaction_error:" <> message
    effect.LoginError(effect.InvalidTokenError) -> "login_error:invalid_token"
    effect.LoginError(effect.TokenUsedError) -> "login_error:token_used"
    effect.LoginError(effect.TokenExpiredError) -> "login_error:token_expired"
    effect.SendEmailError(effect.PublicSendEmailError(message: message)) ->
      "send_email_public:" <> message
    effect.SendEmailError(effect.InternalSendEmailError(message: message)) ->
      "send_email_internal:" <> message
    effect.SessionError(effect.MissingSessionTokenError) ->
      "session_error:missing_session_token"
    effect.SessionError(effect.SessionNotFoundError) ->
      "session_error:session_not_found"
    effect.SessionError(effect.SessionExpiredError) ->
      "session_error:session_expired"
    effect.RunError(effect.PublicRunRequestError(message: message)) ->
      "run_error_public:" <> message
    effect.RunError(effect.InternalRunRequestError(message: message)) ->
      "run_error_internal:" <> message
  }
}

fn effect_error_to_json(err: effect.Error) -> json.Json {
  json.object([
    #("message", json.string(effect_error_to_message(err))),
  ])
}

fn result_to_response(
  ctx: context.Context,
  request: wisp.Request,
  result: Result(ApiResult, effect.Error),
) -> wisp.Response {
  case result {
    Ok(response) -> api_result_to_response(ctx, request, response)
    Error(err) -> error_to_response(err)
  }
}

fn error_to_response(error: effect.Error) -> wisp.Response {
  case error {
    effect.DecodeError(errors) ->
      error_response("decode_error", "Decode error: " <> string.inspect(errors))
    effect.EmailInvalidError(message) -> {
      error_response("email_invalid", "Invalid email: " <> message)
    }
    effect.TooManyRequestsError(count, config) -> {
      error_response(
        "too_many_requests",
        "Too many requests: "
          <> int.to_string(count)
          <> " / "
          <> int.to_string(config.max_requests),
      )
    }
    effect.QueryError(effect.DbQueryError(message: message)) -> {
      wisp.log_error("Query error: " <> message)
      error_response("query_error", "Failed to query data")
    }
    effect.CommandError(effect.DbCommandError(message: message)) -> {
      wisp.log_error("Command error: " <> message)
      error_response("command_error", "Failed to run command")
    }
    effect.TransactionError(effect.DbTransactionError(message: message)) -> {
      wisp.log_error("Transaction error: " <> message)
      error_response("transaction_error", "Transaction failed")
    }
    effect.LoginError(login_error) ->
      case login_error {
        effect.InvalidTokenError -> {
          wisp.log_error("Login error: invalid token")
          error_response("login_error", "Invalid login token")
        }
        effect.TokenUsedError -> {
          wisp.log_error("Login error: token used")
          error_response("login_error", "Login token already used")
        }
        effect.TokenExpiredError -> {
          wisp.log_error("Login error: token expired")
          error_response("login_error", "Login token expired")
        }
      }
    effect.SendEmailError(send_email_error) ->
      case send_email_error {
        effect.PublicSendEmailError(message: message) -> {
          wisp.log_error("Send email error (public): " <> message)
          error_response("send_email_error", message)
        }
        effect.InternalSendEmailError(message: message) -> {
          wisp.log_error("Send email error (private): " <> message)
          error_response("send_email_error", "Failed to send email")
        }
      }
    effect.SessionError(session_error) ->
      case session_error {
        effect.MissingSessionTokenError -> {
          wisp.log_error("Session error: missing session token")
          error_response("session_error", "Missing session token")
        }
        effect.SessionNotFoundError -> {
          wisp.log_error("Session error: session not found")
          error_response("session_error", "Session not found")
        }
        effect.SessionExpiredError -> {
          wisp.log_error("Session error: session expired")
          error_response("session_error", "Session expired")
        }
      }
    effect.RunError(run_request_error) ->
      case run_request_error {
        effect.PublicRunRequestError(message: message) -> {
          wisp.log_error("Run request error (public): " <> message)
          error_response("run_error", message)
        }
        effect.InternalRunRequestError(message: message) -> {
          wisp.log_error("Run request error (private): " <> message)
          error_response("run_error", "Failed to run code")
        }
      }
  }
}
