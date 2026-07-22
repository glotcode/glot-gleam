import gleam/http
import glot_backend/api/handler as api
import glot_backend/logging/ingestion/ports/sink.{type Sink}
import glot_backend/page
import glot_backend/system/application/middleware
import glot_backend/system/effect/runtime.{type Runtime}
import glot_backend/system/file_system
import glot_backend/system/lifecycle/request_tracker/ports/request_tracker.{
  type RequestTracker,
}
import glot_backend/system/lifecycle/server_mode/ports/controller.{
  type Controller,
}
import glot_backend/system/request/context
import wisp

pub fn handle_request(
  effect_runtime: Runtime,
  ctx: context.Context,
  log_sink: Sink,
  request_tracker: RequestTracker,
  server_mode: Controller,
  req: wisp.Request,
) -> wisp.Response {
  use req <- middleware.apply(req, ctx, request_tracker, server_mode)

  case req.method, wisp.path_segments(req) {
    http.Post, ["api", "mux"] ->
      api.handle_request(effect_runtime, ctx, log_sink, req)
    http.Get, ["robots.txt"] ->
      public_static_file(
        ctx.config.static_base_path,
        "robots.txt",
        "text/plain; charset=utf-8",
      )
    http.Get, ["sitemap.xml"] ->
      public_static_file(
        ctx.config.static_base_path,
        "sitemap.xml",
        "application/xml; charset=utf-8",
      )
    http.Get, _ -> page.handle_request(effect_runtime, ctx, log_sink, req)
    _, _ -> wisp.not_found()
  }
}

fn public_static_file(
  static_base_path: String,
  filename: String,
  content_type: String,
) -> wisp.Response {
  case file_system.read_file(static_base_path <> "/" <> filename) {
    Ok(content) ->
      wisp.response(200)
      |> wisp.set_header("content-type", content_type)
      |> wisp.set_header("cache-control", "public, max-age=3600")
      |> wisp.string_body(content)
    Error(_) -> wisp.not_found()
  }
}
