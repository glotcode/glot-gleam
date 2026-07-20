import gleam/erlang/process
import gleam/http
import glot_backend/api/handler as api
import glot_backend/app_config/worker/cache/worker as app_config_cache_worker
import glot_backend/logging/ingestion/ports/sink.{type Sink}
import glot_backend/page
import glot_backend/run_code/worker/language_version_cache/worker as language_version_cache_worker
import glot_backend/system/application/middleware
import glot_backend/system/file_system
import glot_backend/system/lifecycle/request_tracker/ports/request_tracker.{
  type RequestTracker,
}
import glot_backend/system/lifecycle/server_mode/ports/controller.{
  type Controller,
}
import glot_backend/system/request/context
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
  request_tracker: RequestTracker,
  server_mode: Controller,
  req: wisp.Request,
) -> wisp.Response {
  use req <- middleware.apply(req, ctx, request_tracker, server_mode)

  case req.method, wisp.path_segments(req) {
    http.Post, ["api", "mux"] ->
      api.handle_request(
        db,
        ctx,
        app_config_cache_subject,
        language_version_cache_subject,
        log_sink,
        req,
      )
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
    http.Get, _ ->
      page.handle_request(
        db,
        ctx,
        app_config_cache_subject,
        language_version_cache_subject,
        log_sink,
        req,
      )
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
