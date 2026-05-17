import gleam/erlang/process
import gleam/http/request
import gleam/list
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/availability_policy_domain
import glot_backend/editor_page
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/interpreter
import glot_backend/effect/program_state
import glot_backend/effect/runtime
import glot_backend/effect/total_program
import glot_backend/erlang
import glot_backend/home_page
import glot_backend/page/editor_page_domain
import glot_backend/page/snippets_page_domain
import glot_backend/page_error_presenter
import glot_backend/page_layout
import glot_backend/page_response
import glot_backend/server_timing
import glot_backend/snippets_page
import glot_backend/worker/app_config_cache_worker
import glot_backend/worker/language_version_cache_worker
import glot_backend/worker/log_worker
import glot_core/route
import lustre/attribute
import lustre/element
import pog
import wisp

pub type PageRequest {
  PageRequest(route: route.Route, path: String)
}

pub fn handle_request(
  db: pog.Connection,
  ctx: context.Context,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
  log_worker_subject: process.Subject(log_worker.Message),
  req: wisp.Request,
) -> wisp.Response {
  let page_request = page_request_from_request(req)
  let page_response =
    handle_page_request(
      db,
      ctx,
      app_config_cache_subject,
      language_version_cache_subject,
      page_request,
    )
  let total_duration_ns = erlang.perf_counter_ns() - ctx.started_at
  insert_log_entry(
    ctx,
    log_worker_subject,
    page_request,
    page_response,
    total_duration_ns,
  )

  page_response.response
  |> wisp.set_header(
    "Server-Timing",
    server_timing.prepare(page_response.effects, total_duration_ns),
  )
}

fn page_request_from_request(req: wisp.Request) -> PageRequest {
  let uri = request.to_uri(req)
  let path = case uri.query {
    option.Some(query) -> uri.path <> "?" <> query
    option.None -> uri.path
  }

  PageRequest(route: route.from_uri(uri), path: path)
}

fn handle_page_request(
  db: pog.Connection,
  ctx: context.Context,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
  page_request: PageRequest,
) -> page_response.PageResponse {
  let runtime =
    runtime.new(db, app_config_cache_subject, language_version_cache_subject)
  let #(page_decision, availability_state) =
    availability_policy_domain.evaluate_page_route(page_request.route)
    |> interpreter.run(runtime, ctx)

  case page_decision {
    Ok(availability_policy_domain.AllowPage) ->
      handle_page_request_with_runtime(runtime, ctx, page_request)
      |> prepend_effects(availability_state.effect_measurements)
    Ok(availability_policy_domain.UnavailablePage(message, retry_after_seconds)) ->
      page_error_presenter.unavailable_page_response(
        availability_state,
        message,
        retry_after_seconds,
      )
    Error(err) ->
      page_error_presenter.internal_page_error(
        "availability page",
        err,
        availability_state,
      )
  }
}

fn handle_page_request_with_runtime(
  runtime: runtime.Runtime,
  ctx: context.Context,
  page_request: PageRequest,
) -> page_response.PageResponse {
  case page_request.route {
    route.Public(route.Home) -> {
      let state = empty_page_state()
      page_response.PageResponse(
        response: wisp.html_response(
          page_layout.document(
            title: home_page.title(),
            head_children: [],
            app_attributes: [],
            app_children: [home_page.view()],
          ),
          200,
        ),
        status_code: 200,
        render_mode: "ssr",
        effects: [],
        info: state.info_fields,
        warnings: state.warning_fields,
        debug: state.debug_fields,
        error: option.None,
      )
    }
    route.Public(route.Login) -> spa_page("glot.io - login")
    route.Account(route.AccountHome) -> spa_page("glot.io - account")
    route.Account(route.AccountSnippets(_, _)) ->
      spa_page("glot.io - account snippets")
    route.Admin(route.AdminHome) -> spa_page("glot.io - admin")
    route.Admin(route.AdminApiLogs) -> spa_page("glot.io - api logs")
    route.Admin(route.AdminApiLog(_)) -> spa_page("glot.io - api log")
    route.Admin(route.AdminRunLogs) -> spa_page("glot.io - run logs")
    route.Admin(route.AdminRunLog(_)) -> spa_page("glot.io - run log")
    route.Admin(route.AdminPeriodicJobs) -> spa_page("glot.io - periodic jobs")
    route.Admin(route.AdminPeriodicJob(_)) -> spa_page("glot.io - periodic job")
    route.Admin(route.AdminUsers) -> spa_page("glot.io - admin users")
    route.Admin(route.AdminUser(_)) -> spa_page("glot.io - admin user")
    route.Admin(route.AdminJobs) -> spa_page("glot.io - admin jobs")
    route.Admin(route.AdminJob(_)) -> spa_page("glot.io - admin job")
    route.Admin(route.AdminEmailTemplates) ->
      spa_page("glot.io - email templates")
    route.Admin(route.AdminEmailTemplate(_)) ->
      spa_page("glot.io - email template")
    route.Admin(route.AdminSnippets) -> spa_page("glot.io - admin snippets")
    route.Admin(route.AdminSnippet(_)) -> spa_page("glot.io - admin snippet")
    route.Admin(route.AdminJobLogs) -> spa_page("glot.io - job logs")
    route.Admin(route.AdminJobLog(_)) -> spa_page("glot.io - job log")
    route.Admin(route.AdminConfig) -> spa_page("glot.io - admin config")
    route.Admin(route.AdminRateLimits) ->
      spa_page("glot.io - admin rate limits")
    route.Admin(route.AdminJobTypePolicies) ->
      spa_page("glot.io - admin job type policies")
    route.Public(route.Snippets(after:, before:, username:)) ->
      run_page_program(
        "snippets page",
        snippets_page_domain.load_view_model(ctx, after, before, username),
        runtime,
        ctx,
        fn(_) { snippets_page.title() },
        fn(_) { [] },
        snippets_page.app_attributes,
        snippets_page.render,
      )
    route.Public(route.NewSnippet(language_slug)) ->
      run_page_program(
        "new snippet page",
        editor_page_domain.load_new_view_model(language_slug),
        runtime,
        ctx,
        editor_page.title,
        editor_page.head_children,
        editor_page.app_attributes,
        editor_page.render,
      )
    route.Public(route.Snippet(slug)) ->
      run_page_program(
        "snippet page",
        editor_page_domain.load_existing_view_model(ctx, slug),
        runtime,
        ctx,
        editor_page.title,
        editor_page.head_children,
        editor_page.app_attributes,
        editor_page.render,
      )
    route.NotFound(_) -> {
      let state = empty_page_state()
      page_response.PageResponse(
        response: wisp.not_found(),
        status_code: 404,
        render_mode: "not_found",
        effects: [],
        info: state.info_fields,
        warnings: state.warning_fields,
        debug: state.debug_fields,
        error: option.None,
      )
    }
  }
}

fn spa_page(title: String) -> page_response.PageResponse {
  let state = empty_page_state()
  page_response.PageResponse(
    response: wisp.html_response(
      page_layout.document(
        title: title,
        head_children: [],
        app_attributes: [],
        app_children: [],
      ),
      200,
    ),
    status_code: 200,
    render_mode: "spa",
    effects: [],
    info: state.info_fields,
    warnings: state.warning_fields,
    debug: state.debug_fields,
    error: option.None,
  )
}

fn run_page_program(
  page_name: String,
  total_program: total_program.TotalProgram(a),
  runtime: runtime.Runtime,
  ctx: context.Context,
  title: fn(a) -> String,
  head_children: fn(a) -> List(element.Element(Nil)),
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
        response: wisp.html_response(
          page_layout.document(
            title: title(value),
            head_children: head_children(value),
            app_attributes: app_attributes(value),
            app_children: [render(value)],
          ),
          200,
        ),
        status_code: 200,
        render_mode: "ssr",
        effects: state.effect_measurements,
        info: state.info_fields,
        warnings: state.warning_fields,
        debug: state.debug_fields,
        error: option.None,
      )
    Error(err) ->
      page_error_presenter.internal_page_error(page_name, err, state)
  }
}

fn empty_page_state() -> program_state.State {
  program_state.new_state()
}

fn insert_log_entry(
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
  page_request: PageRequest,
  page_response: page_response.PageResponse,
  total_duration_ns: Int,
) -> Nil {
  case process.subject_owner(log_worker_subject) {
    Ok(_) -> {
      process.send(
        log_worker_subject,
        log_worker.InsertPage(prepare_log_entry(
          ctx,
          page_request,
          page_response,
          total_duration_ns,
        )),
      )
      Nil
    }
    Error(_) -> wisp.log_error("Log worker unavailable")
  }
}

fn prepare_log_entry(
  ctx: context.Context,
  page_request: PageRequest,
  page_response: page_response.PageResponse,
  total_duration_ns: Int,
) -> log_worker.PageLogEntry {
  log_worker.PageLogEntry(
    id: basic_handlers.uuid_v7(ctx.timestamp),
    request_id: ctx.request_id,
    created_at: ctx.timestamp,
    route: route.name(page_request.route),
    path: page_request.path,
    status_code: page_response.status_code,
    render_mode: page_response.render_mode,
    duration_ns: total_duration_ns,
    ip: ctx.client_info.ip,
    user_agent: ctx.client_info.user_agent,
    referrer: ctx.client_info.referrer,
    info: page_response.info,
    warnings: page_response.warnings,
    debug: page_response.debug,
    error: page_response.error,
    effects: page_response.effects,
  )
}

fn prepend_effects(
  page_response: page_response.PageResponse,
  effects: List(effect_trace.EffectMeasurement),
) -> page_response.PageResponse {
  page_response.PageResponse(
    ..page_response,
    effects: list.append(effects, page_response.effects),
  )
}
