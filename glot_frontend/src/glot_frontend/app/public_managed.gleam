import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/refresh_session_dto.{type RefreshSessionResponse}
import glot_core/auth/session_dto.{type SessionResponse}
import glot_core/route
import glot_frontend/api/response
import glot_frontend/app/runtime

pub type Model(page_model) {
  Model(route: route.Route, page_model: page_model, runtime: runtime.Model)
}

pub type Msg {
  ClockTicked(Timestamp, page_visible: Bool)
  SessionLoaded(response.Response(option.Option(SessionResponse)))
  SessionRefreshed(response.Response(RefreshSessionResponse))
  PageviewTracked(response.Response(Nil))
  UserNavigatedTo(route.Route)
}

pub type Command(page_command) {
  None
  Batch(List(Command(page_command)))
  RunPage(page_command)
  GetSession
  RefreshSession
  TrackPageview(route.Route)
  ApplyMetadata
  ScheduleTick
  LoadRoute(route.Route)
}

pub fn init(
  initial_route: route.Route,
  now: Timestamp,
  page_visible: Bool,
  init_page: fn(route.Route, runtime.SessionState) ->
    #(page_model, page_command),
) -> #(Model(page_model), Command(page_command)) {
  let app_runtime = runtime.init(now, page_visible)
  let #(page_model, page_command) =
    init_page(initial_route, app_runtime.session)
  #(
    Model(route: initial_route, page_model:, runtime: app_runtime),
    Batch([
      RunPage(page_command),
      TrackPageview(initial_route),
      ApplyMetadata,
      GetSession,
      ScheduleTick,
    ]),
  )
}

pub fn update(
  model: Model(page_model),
  msg: Msg,
  init_page: fn(route.Route, runtime.SessionState) ->
    #(page_model, page_command),
  session_loaded: fn(page_model, runtime.SessionState) -> page_model,
) -> #(Model(page_model), Command(page_command)) {
  case msg {
    ClockTicked(now, page_visible:) -> {
      let #(app_runtime, should_refresh) =
        runtime.tick(model.runtime, now, page_visible)
      #(
        Model(..model, runtime: app_runtime),
        Batch([
          ScheduleTick,
          case should_refresh {
            True -> RefreshSession
            False -> None
          },
        ]),
      )
    }
    SessionLoaded(result) -> {
      let app_runtime = runtime.session_loaded(model.runtime, result)
      #(
        Model(
          ..model,
          runtime: app_runtime,
          page_model: session_loaded(model.page_model, app_runtime.session),
        ),
        None,
      )
    }
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
    UserNavigatedTo(destination) if destination == model.route -> #(model, None)
    UserNavigatedTo(destination) ->
      case route.is_admin_route(destination) {
        True -> #(model, LoadRoute(destination))
        False -> {
          let #(page_model, page_command) =
            init_page(destination, model.runtime.session)
          #(
            Model(..model, route: destination, page_model:),
            Batch([
              RunPage(page_command),
              TrackPageview(destination),
              ApplyMetadata,
            ]),
          )
        }
      }
  }
}
