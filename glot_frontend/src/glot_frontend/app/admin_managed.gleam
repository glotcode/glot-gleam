import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/refresh_session_dto.{type RefreshSessionResponse}
import glot_core/auth/session_dto.{type SessionResponse}
import glot_core/route
import glot_frontend/api/response
import glot_frontend/app/admin_navigation
import glot_frontend/app/runtime

pub type Pages(page_model, page_msg, page_command) {
  Pages(
    empty: fn() -> page_model,
    init: fn(route.AdminRoute, Bool) -> #(page_model, page_command),
    session_loaded: fn(page_model) -> #(page_model, page_command),
    update: fn(page_model, page_msg) -> #(page_model, page_command),
    none: page_command,
  )
}

pub type Model(page_model) {
  Model(route: route.Route, page_model: page_model, runtime: runtime.Model)
}

pub type Msg(page_msg) {
  ClockTicked(Timestamp, page_visible: Bool)
  SessionLoaded(response.Response(option.Option(SessionResponse)))
  SessionRefreshed(response.Response(RefreshSessionResponse))
  PageviewTracked(response.Response(Nil))
  AdminPagesMsg(page_msg)
  UserNavigatedTo(route.Route)
}

pub type Command(page_command) {
  None
  Batch(List(Command(page_command)))
  RunAdmin(page_command)
  GetSession
  RefreshSession
  TrackPageview(route.Route)
  ScheduleTick
  ReplaceRoute(route.Route)
  LoadRoute(route.Route)
}

pub fn init(
  initial_route: route.Route,
  now: Timestamp,
  page_visible: Bool,
  pages: Pages(page_model, page_msg, page_command),
) -> #(Model(page_model), Command(page_command)) {
  let runtime = runtime.init(now, page_visible)
  let #(page_model, page_command) =
    init_page(initial_route, runtime.session, pages)
  #(
    Model(route: initial_route, page_model:, runtime:),
    Batch([
      RunAdmin(page_command),
      TrackPageview(initial_route),
      GetSession,
      ScheduleTick,
    ]),
  )
}

pub fn update(
  model: Model(page_model),
  msg: Msg(page_msg),
  pages: Pages(page_model, page_msg, page_command),
) -> #(Model(page_model), Command(page_command)) {
  case msg {
    ClockTicked(now, page_visible:) -> {
      let #(next_runtime, should_refresh) =
        runtime.tick(model.runtime, now, page_visible)
      #(
        Model(..model, runtime: next_runtime),
        Batch([
          ScheduleTick,
          case should_refresh {
            True -> RefreshSession
            False -> None
          },
        ]),
      )
    }

    SessionLoaded(result) -> session_loaded(model, result, pages)

    SessionRefreshed(result) ->
      case result {
        response.Success(value) -> #(
          Model(
            ..model,
            runtime: runtime.refresh_succeeded(
              model.runtime,
              value.next_heartbeat_in_seconds,
            ),
          ),
          None,
        )
        response.ApiFailure(_) | response.HttpFailure(_) -> #(
          Model(..model, runtime: runtime.refresh_failed(model.runtime)),
          GetSession,
        )
      }

    PageviewTracked(_) -> #(model, None)

    AdminPagesMsg(page_msg) -> {
      let #(page_model, page_command) = pages.update(model.page_model, page_msg)
      #(Model(..model, page_model:), RunAdmin(page_command))
    }

    UserNavigatedTo(destination) -> navigate(model, destination, pages)
  }
}

fn session_loaded(
  model: Model(page_model),
  result: response.Response(option.Option(SessionResponse)),
  pages: Pages(page_model, page_msg, page_command),
) -> #(Model(page_model), Command(page_command)) {
  let next_runtime = runtime.session_loaded(model.runtime, result)
  let session = next_runtime.session
  let next_model = Model(..model, runtime: next_runtime)
  case route.is_admin_route(model.route), runtime.is_admin(session) {
    True, True -> {
      let #(page_model, page_command) = pages.session_loaded(model.page_model)
      #(Model(..next_model, page_model:), RunAdmin(page_command))
    }
    True, False -> #(
      next_model,
      ReplaceRoute(admin_navigation.fallback_route(session)),
    )
    False, _ -> #(next_model, None)
  }
}

fn navigate(
  model: Model(page_model),
  destination: route.Route,
  pages: Pages(page_model, page_msg, page_command),
) -> #(Model(page_model), Command(page_command)) {
  case route.is_admin_route(model.route), route.is_admin_route(destination) {
    True, False -> #(model, LoadRoute(destination))
    _, _ -> {
      let authorized =
        admin_navigation.authorized_route(destination, model.runtime.session)
      let #(page_model, page_command) =
        init_page(authorized, model.runtime.session, pages)
      #(
        Model(..model, route: authorized, page_model:),
        Batch([RunAdmin(page_command), TrackPageview(authorized)]),
      )
    }
  }
}

fn init_page(
  target: route.Route,
  session: runtime.SessionState,
  pages: Pages(page_model, page_msg, page_command),
) -> #(page_model, page_command) {
  case target {
    route.Admin(admin_route) ->
      pages.init(admin_route, runtime.is_admin(session))
    route.Public(_) | route.Account(_) | route.NotFound(_) -> #(
      pages.empty(),
      pages.none,
    )
  }
}
