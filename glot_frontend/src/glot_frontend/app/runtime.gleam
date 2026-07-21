import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/session_dto.{type SessionResponse}
import glot_core/auth/user_model
import glot_core/email/email_address_model.{type EmailAddress}
import glot_core/helpers/timestamp_helpers
import glot_core/route
import glot_frontend/api/response as api_response
import glot_frontend/ui/string_helpers
import glot_web/page/top_bar
import youid/uuid

pub type SessionState {
  LoadingSession
  AnonymousSession
  AuthenticatedSession(SessionResponse)
  SessionError
}

pub const default_heartbeat_interval_seconds = 60

pub type Model {
  Model(
    session: SessionState,
    now: Timestamp,
    page_visible: Bool,
    heartbeat_in_flight: Bool,
    last_heartbeat_at: option.Option(Timestamp),
    heartbeat_interval_seconds: Int,
  )
}

pub fn init(now: Timestamp, page_visible: Bool) -> Model {
  Model(
    session: LoadingSession,
    now:,
    page_visible:,
    heartbeat_in_flight: False,
    last_heartbeat_at: option.None,
    heartbeat_interval_seconds: default_heartbeat_interval_seconds,
  )
}

pub fn tick(
  model: Model,
  now: Timestamp,
  page_visible: Bool,
) -> #(Model, Bool) {
  let visible_model = Model(..model, now:, page_visible:)
  let refresh =
    should_refresh_session(
      visible_model.session,
      visible_model.page_visible,
      visible_model.heartbeat_in_flight,
      visible_model.last_heartbeat_at,
      visible_model.heartbeat_interval_seconds,
      visible_model.now,
    )

  case refresh {
    True -> #(
      Model(
        ..visible_model,
        heartbeat_in_flight: True,
        last_heartbeat_at: option.Some(now),
      ),
      True,
    )
    False -> #(visible_model, False)
  }
}

pub fn session_loaded(
  model: Model,
  response: api_response.Response(option.Option(SessionResponse)),
) -> Model {
  Model(
    ..model,
    session: session_from_response(response),
    heartbeat_in_flight: False,
  )
}

pub fn refresh_succeeded(model: Model, next_interval_seconds: Int) -> Model {
  Model(
    ..model,
    heartbeat_in_flight: False,
    heartbeat_interval_seconds: next_interval_seconds,
  )
}

pub fn refresh_failed(model: Model) -> Model {
  Model(..model, heartbeat_in_flight: False)
}

pub fn session_from_response(
  response: api_response.Response(option.Option(SessionResponse)),
) -> SessionState {
  case response {
    api_response.Success(option.Some(session)) -> AuthenticatedSession(session)
    api_response.Success(option.None) -> AnonymousSession
    api_response.ApiFailure(_) | api_response.HttpFailure(_) -> SessionError
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

pub fn current_user_email(
  session: SessionState,
) -> option.Option(EmailAddress) {
  case session {
    AuthenticatedSession(session) -> option.Some(session.user.email)
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
