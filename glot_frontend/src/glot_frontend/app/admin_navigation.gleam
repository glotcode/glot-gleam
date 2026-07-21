import glot_core/route
import glot_frontend/app/runtime

pub fn authorized_route(
  target: route.Route,
  session: runtime.SessionState,
) -> route.Route {
  case route.is_admin_route(target) {
    True ->
      case runtime.is_admin(session) {
        True -> target
        False -> fallback_route(session)
      }
    False -> target
  }
}

pub fn fallback_route(session: runtime.SessionState) -> route.Route {
  case session {
    runtime.AnonymousSession | runtime.SessionError -> route.Public(route.Login)
    runtime.AuthenticatedSession(_) | runtime.LoadingSession ->
      route.Public(route.Home)
  }
}
