import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import glot_backend/context
import glot_backend/domain/run_domain
import glot_backend/domain/send_login_token_domain
import glot_backend/log
import glot_backend/program
import glot_backend/program/handlers as program_handlers
import glot_core/run
import glot_core/timestamp_helpers
import wisp
import youid/uuid

pub fn handle_request(ctx: context.Context, req: wisp.Request) -> wisp.Response {
  use json_body <- wisp.require_json(req)
  case handle_decoded_request(ctx, json_body) {
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

  let #(
    api_result,
    program.State(effect_timings: effect_timings, log_fields: _),
  ) =
    handle_api_request(ctx, api_request)
    |> program.run(handlers)
  let _ = wisp.log_info("Effect timings: " <> string.inspect(effect_timings))

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

pub fn new_log_entry(
  ctx: context.Context,
  state: program.State,
  action: ApiAction,
) -> program.Program(LogEntry) {
  use req_id <- program.and_then(program.uuid_v7())
  use now <- program.and_then(program.system_time())
  let assert Ok(request_id) = uuid.from_bit_array(req_id)

  let utc_time = timestamp.to_rfc3339(ctx.timestamp, calendar.utc_offset)

  let entry =
    LogEntry(
      request_id: uuid.to_string(request_id),
      timestamp: utc_time,
      action: api_action_to_string(action),
      duration_ns: timestamp_helpers.duration_in_ns(now, ctx.timestamp),
      user_agent: ctx.client_user_agent,
      fields: state.log_fields,
      effects: [],
    )

  program.succeed(entry)
}

pub type LogEntry {
  LogEntry(
    request_id: String,
    timestamp: String,
    action: String,
    duration_ns: Int,
    user_agent: option.Option(String),
    fields: Dict(String, log.Value),
    effects: List(EffectEntry),
  )
}

pub type EffectEntry {
  EffectEntry(name: String, duration_ns: Int)
}
