import gleam/option
import glot_backend/api/model/api_result.{type ApiResult}
import glot_backend/api/model/request.{type ApiRequest}
import glot_backend/logging/api_log/model/entry as api_log_entry
import glot_backend/logging/ingestion/ports/sink.{type Sink}
import glot_backend/logging/pageview/model/entry as pageview_entry
import glot_backend/system/effect/basic/basic_handlers
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/request/context

pub fn insert(
  ctx: context.Context,
  sink: Sink,
  state: program_state.State,
  request: ApiRequest,
  total_duration_ns: Int,
  result: Result(ApiResult, error.Error),
) -> Nil {
  let maybe_error = case result {
    Ok(_) -> option.None
    Error(error) -> option.Some(error)
  }

  sink.write_api(prepare_api_entry(
    ctx,
    state,
    request,
    total_duration_ns,
    maybe_error,
  ))
  insert_pageview_entry(ctx, sink, result)
}

fn insert_pageview_entry(
  ctx: context.Context,
  sink: Sink,
  result: Result(ApiResult, error.Error),
) -> Nil {
  case result {
    Ok(api_result.TrackPageviewResponse(pageview)) ->
      sink.write_pageview(pageview_entry.Entry(
        id: pageview.id,
        created_at: ctx.timestamp,
        session_id: pageview.session_id,
        user_id: pageview.user_id,
        route: pageview.route,
        path: pageview.path,
        user_agent: ctx.client_info.user_agent,
        ip: ctx.client_info.ip,
      ))
    Ok(_) | Error(_) -> Nil
  }
}

fn prepare_api_entry(
  ctx: context.Context,
  state: program_state.State,
  request: ApiRequest,
  total_duration_ns: Int,
  error: option.Option(error.Error),
) -> api_log_entry.Entry {
  api_log_entry.Entry(
    id: basic_handlers.uuid_v7(ctx.timestamp),
    request_id: ctx.request_id,
    created_at: ctx.timestamp,
    action: request.action,
    body_bytes: request.bytes,
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
