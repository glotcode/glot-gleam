import gleam/erlang/process
import gleam/http/request
import gleam/option
import gleam/string
import glot_backend/context
import glot_backend/effect/error
import glot_backend/effect/interpreter
import glot_backend/effect/program_state
import glot_backend/effect/runtime
import glot_backend/effect/total_program
import glot_backend/erlang
import glot_backend/home_page
import glot_backend/page_layout
import glot_backend/page/snippets_page_domain
import glot_backend/page_response
import glot_backend/server_timing
import glot_backend/snippets_page
import glot_backend/worker/language_version_cache_worker
import glot_core/language
import glot_core/route
import lustre/attribute
import lustre/element
import pog
import wisp

pub type PageRequest {
  PageRequest(route: route.Route)
}

pub fn handle_request(
  db: pog.Connection,
  ctx: context.Context,
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
  req: wisp.Request,
) -> wisp.Response {
  let page_request = page_request_from_request(req)
  let page_response =
    handle_page_request(db, ctx, language_version_cache_subject, page_request)
  let total_duration_ns = erlang.perf_counter_ns() - ctx.started_at

  page_response.response
  |> wisp.set_header(
    "Server-Timing",
    server_timing.prepare(page_response.effects, total_duration_ns),
  )
}

fn page_request_from_request(req: wisp.Request) -> PageRequest {
  req
  |> request.to_uri
  |> route.from_uri
  |> fn(current_route) { PageRequest(route: current_route) }
}

fn handle_page_request(
  db: pog.Connection,
  ctx: context.Context,
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
  page_request: PageRequest,
) -> page_response.PageResponse {
  let runtime = runtime.new(db, language_version_cache_subject)

  case page_request.route {
    route.Home ->
      page_response.PageResponse(
        wisp.html_response(
          page_layout.document(
            title: home_page.title(),
            app_attributes: [],
            app_children: [home_page.view()],
          ),
          200,
        ),
        [],
      )
    route.Login -> spa_page("glot.io - login")
    route.Account -> spa_page("glot.io - account")
    route.AccountSnippets(_, _) -> spa_page("glot.io - account snippets")
    route.Snippets(after:, before:, username:) ->
      run_page_program(
        "snippets page",
        snippets_page_domain.load_view_model(ctx, after, before, username),
        runtime,
        ctx,
        snippets_page.title(),
        snippets_page.app_attributes,
        snippets_page.render,
      )
    route.NewSnippet(language_slug) -> spa_page(new_snippet_title(language_slug))
    route.Snippet(_) -> spa_page("glot.io - snippet")
    route.NotFound(_) -> page_response.PageResponse(wisp.not_found(), [])
  }
}

fn spa_page(title: String) -> page_response.PageResponse {
  page_response.PageResponse(
    wisp.html_response(
      page_layout.document(
        title: title,
        app_attributes: [],
        app_children: [],
      ),
      200,
    ),
    [],
  )
}

fn new_snippet_title(language_slug: String) -> String {
  case language.from_string(language_slug) {
    option.Some(lang) -> "glot.io - new " <> language.name(lang) <> " snippet"
    option.None -> "glot.io - new " <> language_slug <> " snippet"
  }
}

fn run_page_program(
  page_name: String,
  total_program: total_program.TotalProgram(a),
  runtime: runtime.Runtime,
  ctx: context.Context,
  title: String,
  app_attributes: fn(a) -> List(attribute.Attribute(Nil)),
  render: fn(a) -> element.Element(Nil),
) -> page_response.PageResponse {
  let #(result, state) =
    total_program
    |> total_program.to_program
    |> interpreter.run(runtime, ctx)

  case result {
    Ok(value) ->
      page_response.PageResponse(
        wisp.html_response(
          page_layout.document(
            title: title,
            app_attributes: app_attributes(value),
            app_children: [render(value)],
          ),
          200,
        ),
        state.effect_measurements,
      )
    Error(err) -> internal_page_error(page_name, err, state)
  }
}

fn internal_page_error(
  page_name: String,
  err: error.Error,
  state: program_state.State,
) -> page_response.PageResponse {
  wisp.log_error(
    "TotalProgram failed unexpectedly for "
    <> page_name
    <> ": "
    <> string.inspect(err),
  )
  page_response.PageResponse(
    wisp.html_response("Internal Server Error", 500),
    state.effect_measurements,
  )
}
