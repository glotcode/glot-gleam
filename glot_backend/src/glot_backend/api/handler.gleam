import gleam/bit_array
import gleam/erlang/process
import gleam/json
import gleam/string
import glot_backend/admin/adapter/api/handler as admin_api_handler
import glot_backend/api/dispatcher/public as public_dispatcher
import glot_backend/api/logging as api_logging
import glot_backend/api/model/api_result.{type ApiResult}
import glot_backend/api/model/request.{type ApiRequest}
import glot_backend/api/presenter/error as api_error_presenter
import glot_backend/api/presenter/response as response_presenter
import glot_backend/app_config/effect/effect as app_config_effect
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/app_config/worker/cache/worker as app_config_cache_worker
import glot_backend/logging/ingestion/ports/sink.{type Sink}
import glot_backend/request_policy/availability as availability_policy
import glot_backend/run_code/worker/language_version_cache/worker as language_version_cache_worker
import glot_backend/system/effect/adapter/cache_ports
import glot_backend/system/effect/adapter/service_ports as service_ports_adapter
import glot_backend/system/effect/error
import glot_backend/system/effect/interpreter
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/effect/runtime
import glot_backend/system/request/context
import glot_backend/system/request/hydrated_context as request_context
import glot_backend/system/runtime/erlang
import glot_core/api_action
import pog
import wisp

pub fn handle_request(
  db: pog.Connection,
  ctx: context.Context,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
  log_sink: Sink,
  req: wisp.Request,
) -> wisp.Response {
  use <- wisp.require_content_type(req, "application/json")
  use api_request <- require_api_request(ctx, req)
  let effect_runtime =
    runtime.new(service_ports_adapter.new(
      db,
      cache_ports.new(app_config_cache_subject, language_version_cache_subject),
    ))

  let #(api_result, state) =
    handle_api_request(ctx, api_request)
    |> interpreter.run(effect_runtime, ctx)

  let total_duration_ns = erlang.perf_counter_ns() - ctx.started_at
  api_logging.insert(
    ctx,
    log_sink,
    state,
    api_request,
    total_duration_ns,
    api_result,
  )
  response_presenter.from_result(
    ctx,
    req,
    api_request.action,
    state.effect_measurements,
    total_duration_ns,
    api_result,
  )
}

fn handle_api_request(
  ctx: context.Context,
  api_request: ApiRequest,
) -> program_types.Program(ApiResult) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let request_ctx = request_context.new(ctx, config)
  use _ <- program.and_then(availability_policy.enforce_api_action(
    dynamic_config.availability_config(config),
    api_request.action,
  ))
  case api_request.action {
    api_action.PublicAction(action) ->
      public_dispatcher.dispatch(request_ctx, action, api_request.data)
    api_action.AdminAction(action) ->
      admin_api_handler.dispatch(request_ctx, action, api_request.data)
  }
}

fn require_api_request(
  ctx: context.Context,
  request: wisp.Request,
  next: fn(ApiRequest) -> wisp.Response,
) -> wisp.Response {
  case wisp.read_body_bits(request) {
    Ok(bits) ->
      case bit_array.to_string(bits) {
        Ok(body) ->
          case json.parse(body, request.decoder(bit_array.byte_size(bits))) {
            Ok(api_request) -> next(api_request)
            Error(decode_errors) ->
              response_presenter.error(
                ctx,
                400,
                "invalid_api_request",
                "Failed to decode as api request: "
                  <> string.inspect(decode_errors),
              )
          }
        Error(_) ->
          response_presenter.error(
            ctx,
            400,
            "invalid_utf8",
            "Request body is not valid UTF-8",
          )
      }
    Error(_) ->
      response_presenter.error(
        ctx,
        400,
        "body_read_error",
        "Failed to read request body",
      )
  }
}

pub fn error_status(error: error.Error) -> Int {
  api_error_presenter.error_status(error)
}

pub fn api_error_details(error: error.Error) -> #(Int, String, String) {
  api_error_presenter.error_details(error)
}
