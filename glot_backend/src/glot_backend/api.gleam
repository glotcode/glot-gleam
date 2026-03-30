import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import glot_backend/api_action.{type ApiAction}
import glot_backend/context
import glot_backend/domain/api/login_domain
import glot_backend/domain/api/run_domain
import glot_backend/domain/api/send_login_token_domain
import glot_backend/domain/api/snippet_create_domain
import glot_backend/log
import glot_backend/log_worker
import glot_backend/program
import glot_backend/program/handlers as program_handlers
import glot_core/run
import glot_core/timestamp_helpers
import wisp

pub fn handle_request(
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
  req: wisp.Request,
) -> wisp.Response {
  use json_body <- wisp.require_json(req)
  case handle_decoded_request(ctx, log_worker_subject, req, json_body) {
    Ok(response) -> response
    Error(response) -> response
  }
}

fn result_to_response(
  ctx: context.Context,
  request: wisp.Request,
  result: Result(ApiResult, program.Error),
) -> wisp.Response {
  case result {
    Ok(response) -> api_result_to_response(ctx, request, response)
    Error(err) -> error_to_response(err)
  }
}

fn error_to_response(error: program.Error) -> wisp.Response {
  case error {
    program.DecodeError(errors) ->
      error_response("decode_error", "Decode error: " <> string.inspect(errors))
    program.EmailInvalidError(message) -> {
      error_response("email_invalid", "Invalid email: " <> message)
    }
    program.TooManyRequestsError(count, config) -> {
      error_response(
        "too_many_requests",
        "Too many requests: "
          <> int.to_string(count)
          <> " / "
          <> int.to_string(config.max_requests),
      )
    }
    program.QueryError(program.DbQueryError(message: message)) -> {
      wisp.log_error("Query error: " <> message)
      error_response("query_error", "Failed to query data")
    }
    program.CommandError(program.DbCommandError(message: message)) -> {
      wisp.log_error("Command error: " <> message)
      error_response("command_error", "Failed to run command")
    }
    program.TransactionError(program.DbTransactionError(message: message)) -> {
      wisp.log_error("Transaction error: " <> message)
      error_response("transaction_error", "Transaction failed")
    }
    program.LoginError(login_error) ->
      case login_error {
        program.InvalidTokenError -> {
          wisp.log_error("Login error: invalid token")
          error_response("login_error", "Invalid login token")
        }
        program.TokenUsedError -> {
          wisp.log_error("Login error: token used")
          error_response("login_error", "Login token already used")
        }
        program.TokenExpiredError -> {
          wisp.log_error("Login error: token expired")
          error_response("login_error", "Login token expired")
        }
      }
    program.SendEmailError(send_email_error) ->
      case send_email_error {
        program.PublicSendEmailError(message: message) -> {
          wisp.log_error("Send email error (public): " <> message)
          error_response("send_email_error", message)
        }
        program.InternalSendEmailError(message: message) -> {
          wisp.log_error("Send email error (private): " <> message)
          error_response("send_email_error", "Failed to send email")
        }
      }
    program.SessionError(session_error) ->
      case session_error {
        program.MissingSessionTokenError -> {
          wisp.log_error("Session error: missing session token")
          error_response("session_error", "Missing session token")
        }
        program.SessionNotFoundError -> {
          wisp.log_error("Session error: session not found")
          error_response("session_error", "Session not found")
        }
        program.SessionExpiredError -> {
          wisp.log_error("Session error: session expired")
          error_response("session_error", "Session expired")
        }
      }
    program.RunError(run_request_error) ->
      case run_request_error {
        program.PublicRunRequestError(message: message) -> {
          wisp.log_error("Run request error (public): " <> message)
          error_response("run_error", message)
        }
        program.InternalRunRequestError(message: message) -> {
          wisp.log_error("Run request error (private): " <> message)
          error_response("run_error", "Failed to run code")
        }
      }
  }
}

fn handle_api_request(
  ctx: context.Context,
  api_request: ApiRequest,
) -> program.Program(ApiResult) {
  case api_request.action {
    api_action.RunAction ->
      run_domain.run(ctx, api_request.data)
      |> program.map(RunResultResponse)
    api_action.SnippetCreateAction ->
      snippet_create_domain.snippet_create(ctx, api_request.data)
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
  ApiRequest(action: ApiAction, data: dynamic.Dynamic)
}

type ApiResult {
  RunResultResponse(run.RunResult)
  LoginResponse(session_token: String)
  NoContentResponse
}

pub fn api_request_decoder() -> decode.Decoder(ApiRequest) {
  use action <- decode.field("action", api_action.decoder())
  use data <- decode.field("data", decode.dynamic)
  decode.success(ApiRequest(action:, data:))
}

fn handle_decoded_request(
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
  req: wisp.Request,
  json_body: dynamic.Dynamic,
) -> Result(wisp.Response, wisp.Response) {
  use api_request <- result.try(
    decode.run(json_body, api_request_decoder())
    |> result.map_error(fn(decode_errors) {
      error_response(
        "invalid_request",
        "Invalid request: " <> string.inspect(decode_errors),
      )
    }),
  )
  let handlers = program_handlers.from_context(ctx)

  let #(api_result, state) =
    handle_api_request(ctx, api_request)
    |> program.run(handlers)

  let _ =
    insert_log_entry(
      ctx,
      log_worker_subject,
      state,
      api_request.action,
      api_result,
    )

  Ok(result_to_response(ctx, req, api_result))
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
  state: program.State,
  action: ApiAction,
  result: Result(ApiResult, program.Error),
) -> Nil {
  let error = case result {
    Ok(_) -> option.None
    Error(err) -> option.Some(program_error_to_message(err))
  }

  case process.subject_owner(log_worker_subject) {
    Ok(_) -> {
      process.send(
        log_worker_subject,
        log_worker.Insert(save_log_entry(ctx, state, action, error)),
      )
      Nil
    }
    Error(_) -> wisp.log_error("Log worker unavailable")
  }
}

fn save_log_entry(
  ctx: context.Context,
  state: program.State,
  action: ApiAction,
  error: option.Option(String),
) -> log_worker.LogEntry {
  let handlers = program_handlers.from_context(ctx)
  let id = handlers.uuid_v7()
  let now = handlers.system_time()

  log_worker.LogEntry(
    id: id,
    request_id: ctx.request_id,
    created_at: ctx.timestamp,
    action: api_action.to_string(action),
    duration_ns: timestamp_helpers.duration_in_ns(now, ctx.timestamp),
    ip: ctx.client_info.ip,
    user_agent: ctx.client_info.user_agent,
    error: error,
    data: state.log_fields |> log.encode_fields |> json.to_string,
    effects: state.effect_timings |> effects_to_json |> json.to_string,
  )
}

fn effect_name_to_string(effect_name: program.EffectName) -> String {
  case effect_name {
    program.NewTokenEffect -> "new_token"
    program.SystemTimeEffect -> "system_time"
    program.UuidV7Effect -> "uuid_v7"
    program.LogEffect -> "log"
    program.PostRunRequestEffect -> "post_run_request"
    program.SendEmailEffect -> "send_email"
    program.RunQueryEffect(query_name) ->
      "run_query:" <> db_query_name_to_string(query_name)
    program.RunCommandEffect(command_name) ->
      "run_command:" <> db_command_name_to_string(command_name)
    program.RunInTransactionEffect(command_names) ->
      "run_in_transaction:"
      <> string.join(list.map(command_names, db_command_name_to_string), ",")
    program.CustomEffect(name) -> "custom:" <> name
  }
}

fn db_query_name_to_string(query_name: program.DbQueryName) -> String {
  case query_name {
    program.DbGetUserByEmailQuery -> "db_get_user_by_email"
    program.DbListLoginTokensByUserQuery -> "db_list_login_tokens_by_user"
    program.DbGetSessionByTokenQuery -> "db_get_session_by_token"
    program.DbGetNextJobQuery -> "db_get_next_job"
    program.DbCountUserActivitiesByIpQuery -> "db_count_user_activities_by_ip"
    program.DbCountUserActivitiesByUserQuery ->
      "db_count_user_activities_by_user"
  }
}

fn db_command_name_to_string(command_name: program.DbCommandName) -> String {
  case command_name {
    program.DbInsertUserCommand -> "db_insert_user"
    program.DbInsertJobCommand -> "db_insert_job"
    program.DbInsertSnippetCommand -> "db_insert_snippet"
    program.DbInsertSessionCommand -> "db_insert_session"
    program.DbInsertLoginTokenCommand -> "db_insert_login_token"
    program.DbUpdateLoginTokenCommand -> "db_update_login_token"
    program.DbInsertUserActivityCommand -> "db_insert_user_activity"
    program.DbInsertLogEntryCommand -> "db_insert_log_entry"
    program.DbMarkJobDoneCommand -> "db_mark_job_done"
    program.DbRescheduleJobCommand -> "db_reschedule_job"
  }
}

fn effects_to_json(effects: List(program.EffectTiming)) -> json.Json {
  json.array(effects, effect_timing_to_json)
}

fn effect_timing_to_json(effect_timing: program.EffectTiming) -> json.Json {
  let #(effect_name, duration_ns) = effect_timing
  json.object([
    #("name", json.string(effect_name_to_string(effect_name))),
    #("duration_ns", json.int(duration_ns)),
  ])
}

fn program_error_to_message(err: program.Error) -> String {
  case err {
    program.DecodeError(errors) -> "decode_error:" <> string.inspect(errors)
    program.EmailInvalidError(message) -> "email_invalid:" <> message
    program.TooManyRequestsError(count, _) ->
      "too_many_requests:" <> int.to_string(count)
    program.QueryError(program.DbQueryError(message: message)) ->
      "query_error:" <> message
    program.CommandError(program.DbCommandError(message: message)) ->
      "command_error:" <> message
    program.TransactionError(program.DbTransactionError(message: message)) ->
      "transaction_error:" <> message
    program.LoginError(program.InvalidTokenError) -> "login_error:invalid_token"
    program.LoginError(program.TokenUsedError) -> "login_error:token_used"
    program.LoginError(program.TokenExpiredError) -> "login_error:token_expired"
    program.SendEmailError(program.PublicSendEmailError(message: message)) ->
      "send_email_public:" <> message
    program.SendEmailError(program.InternalSendEmailError(message: message)) ->
      "send_email_internal:" <> message
    program.SessionError(program.MissingSessionTokenError) ->
      "session_error:missing_session_token"
    program.SessionError(program.SessionNotFoundError) ->
      "session_error:session_not_found"
    program.SessionError(program.SessionExpiredError) ->
      "session_error:session_expired"
    program.RunError(program.PublicRunRequestError(message: message)) ->
      "run_error_public:" <> message
    program.RunError(program.InternalRunRequestError(message: message)) ->
      "run_error_internal:" <> message
  }
}
