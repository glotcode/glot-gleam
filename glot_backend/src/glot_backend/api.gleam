import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/erlang/process
import glot_backend/context
import glot_backend/domain/run_domain
import glot_backend/log_worker
import glot_backend/domain/send_login_token_domain
import glot_backend/log
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
  case handle_decoded_request(ctx, log_worker_subject, json_body) {
    Ok(response) -> response
    Error(response) -> response
  }
}

fn result_to_response(result: Result(ApiResult, program.Error)) -> wisp.Response {
  case result {
    Ok(response) -> api_result_to_response(response)
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
    RunAction ->
      run_domain.handle_run(ctx, api_request.data)
      |> program.map(RunResultResponse)
    SendLoginTokenAction ->
      send_login_token_domain.send_login_token(ctx, api_request.data)
      |> program.map(fn(_) { NoContentResponse })
  }
}

pub type ApiAction {
  RunAction
  SendLoginTokenAction
}

pub type ApiRequest {
  ApiRequest(action: ApiAction, data: dynamic.Dynamic)
}

type ApiResult {
  RunResultResponse(run.RunResult)
  NoContentResponse
}

pub fn api_request_decoder() -> decode.Decoder(ApiRequest) {
  use action <- decode.field("action", api_action_decoder())
  use data <- decode.field("data", decode.dynamic)
  decode.success(ApiRequest(action:, data:))
}

fn api_action_decoder() -> decode.Decoder(ApiAction) {
  use action <- decode.then(decode.string)
  case action {
    "Run" -> decode.success(RunAction)
    "SendLoginToken" -> decode.success(SendLoginTokenAction)
    _ -> decode.failure(RunAction, "ApiAction")
  }
}

pub fn api_action_to_string(action: ApiAction) {
  case action {
    RunAction -> "Run"
    SendLoginTokenAction -> "SendLoginToken"
  }
}

fn handle_decoded_request(
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
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

  let _ = insert_log_entry(ctx, log_worker_subject, state, api_request.action, api_result)

  Ok(result_to_response(api_result))
}

fn api_result_to_response(result: ApiResult) -> wisp.Response {
  case result {
    RunResultResponse(run_result) -> {
      success_response(run.encode_run_result(run_result))
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
    created_at: ctx.timestamp,
    action: api_action_to_string(action),
    duration_ns: timestamp_helpers.duration_in_ns(now, ctx.timestamp),
    user_agent: ctx.client_user_agent,
    error: error,
    fields: state.log_fields |> log.encode_fields |> json.to_string,
    effects: state.effect_timings |> effects_to_json |> json.to_string,
  )
}

fn effect_name_to_string(effect_name: program.EffectName) -> String {
  case effect_name {
    program.RandomStringEffect -> "random_string"
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
    program.DbGetNextJobQuery -> "db_get_next_job"
    program.DbCountUserActivitiesByIpAndActionQuery ->
      "db_count_user_activities_by_ip_and_action"
  }
}

fn db_command_name_to_string(command_name: program.DbCommandName) -> String {
  case command_name {
    program.DbInsertUserCommand -> "db_insert_user"
    program.DbInsertJobCommand -> "db_insert_job"
    program.DbInsertLoginTokenCommand -> "db_insert_login_token"
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
    program.SendEmailError(program.PublicSendEmailError(message: message)) ->
      "send_email_public:" <> message
    program.SendEmailError(program.InternalSendEmailError(message: message)) ->
      "send_email_internal:" <> message
    program.RunError(program.PublicRunRequestError(message: message)) ->
      "run_error_public:" <> message
    program.RunError(program.InternalRunRequestError(message: message)) ->
      "run_error_internal:" <> message
  }
}
