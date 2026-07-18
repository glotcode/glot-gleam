import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/session_dto.{type SessionResponse}
import glot_core/auth/user_model
import glot_core/helpers/timestamp_helpers
import glot_core/page/top_bar
import glot_core/pageview_dto
import glot_core/route
import glot_frontend/api
import glot_frontend/app_event
import glot_frontend/string_helpers
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import youid/uuid

pub type SessionState {
  LoadingSession
  AnonymousSession
  AuthenticatedSession(SessionResponse)
  SessionError
}

pub const default_heartbeat_interval_seconds = 60

pub fn session_from_response(
  response: api.ApiResponse(option.Option(SessionResponse)),
) -> SessionState {
  case response {
    api.ApiSuccess(option.Some(session)) -> AuthenticatedSession(session)
    api.ApiSuccess(option.None) -> AnonymousSession
    api.ApiFailure(_) | api.HttpFailure(_) -> SessionError
  }
}

pub fn is_authenticated(session: SessionState) -> Bool {
  case session {
    AuthenticatedSession(_) -> True
    LoadingSession | AnonymousSession | SessionError -> False
  }
}

pub fn is_admin(session: SessionState) -> Bool {
  case session {
    AuthenticatedSession(session) -> session.user.role == user_model.AdminUser
    LoadingSession | AnonymousSession | SessionError -> False
  }
}

pub fn current_user_id(session: SessionState) -> option.Option(uuid.Uuid) {
  case session {
    AuthenticatedSession(session) -> option.Some(session.user.id)
    LoadingSession | AnonymousSession | SessionError -> option.None
  }
}

pub fn current_user_label(session: SessionState) -> String {
  case session {
    AuthenticatedSession(session) ->
      case string.length(session.user.username) > 20 {
        True -> string_helpers.truncate_stem_middle(session.user.username, 20)
        False -> session.user.username
      }
    LoadingSession | AnonymousSession | SessionError -> "Account"
  }
}

pub fn current_user_route(session: SessionState) -> route.Route {
  case session {
    AuthenticatedSession(_) | LoadingSession -> route.Account(route.AccountHome)
    AnonymousSession | SessionError -> route.Public(route.Login)
  }
}

pub fn navigation_actions(
  session: SessionState,
  current_route: route.Route,
  query: String,
  on_navigate: fn(route.Route) -> msg,
) -> List(top_bar.Action(msg)) {
  let navigation_state = case session {
    AuthenticatedSession(_) ->
      case is_admin(session) {
        True -> top_bar.CanManageAdmin
        False -> top_bar.CanManageAccount
      }
    LoadingSession -> top_bar.CanManageAccount
    AnonymousSession | SessionError -> top_bar.NeedsLogin
  }

  top_bar.navigation_actions(
    navigation_state:,
    current_route:,
    query:,
    on_navigate:,
  )
}

pub fn should_refresh_session(
  session: SessionState,
  page_visible: Bool,
  heartbeat_in_flight: Bool,
  last_heartbeat_at: option.Option(Timestamp),
  heartbeat_interval_seconds: Int,
  now: Timestamp,
) -> Bool {
  case is_authenticated(session), page_visible, heartbeat_in_flight {
    True, True, False ->
      heartbeat_is_due(heartbeat_interval_seconds, last_heartbeat_at, now)
    _, _, _ -> False
  }
}

fn heartbeat_is_due(
  heartbeat_interval_seconds: Int,
  last_heartbeat_at: option.Option(Timestamp),
  now: Timestamp,
) -> Bool {
  case last_heartbeat_at {
    option.None -> True
    option.Some(last_heartbeat_at) ->
      timestamp_helpers.to_microseconds(now)
      - timestamp_helpers.to_microseconds(last_heartbeat_at)
      >= heartbeat_interval_seconds * 1_000_000
  }
}

pub fn track_pageview(
  destination: route.Route,
  callback: fn(api.ApiResponse(Nil)) -> msg,
) -> Effect(msg) {
  let #(path, query) = route.path_and_query(destination)
  let full_path = case query {
    option.Some(query) -> path <> "?" <> query
    option.None -> path
  }

  api.track_pageview(
    pageview_dto.PageviewRequest(
      id: uuid.v7(),
      route: route.name(destination),
      path: full_path,
    ),
    callback,
  )
}

pub fn apply_app_event(
  page_effect: Effect(msg),
  event: app_event.AppEvent,
  session_loaded: fn(api.ApiResponse(option.Option(SessionResponse))) -> msg,
) -> Effect(msg) {
  case event {
    app_event.NoAppEvent -> page_effect
    app_event.RefreshSession ->
      effect.batch([page_effect, api.get_session(session_loaded)])
  }
}

pub fn not_found_view() -> Element(msg) {
  html.main(
    [
      attribute.id("main-content"),
      attribute.attribute("tabindex", "-1"),
    ],
    [
      html.h1([], [html.text("404 Not Found")]),
    ],
  )
}
