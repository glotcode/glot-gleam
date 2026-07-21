import gleam/option
import glot_core/auth/session_dto.{type SessionResponse}
import glot_core/pageview_dto
import glot_core/route
import glot_frontend/api/account
import glot_frontend/api/public
import glot_frontend/api/response
import glot_frontend/app/event
import lustre/effect.{type Effect}
import youid/uuid

pub fn track_pageview(
  destination: route.Route,
  callback: fn(response.Response(Nil)) -> msg,
) -> Effect(msg) {
  let #(path, query) = route.path_and_query(destination)
  let full_path = case query {
    option.Some(query) -> path <> "?" <> query
    option.None -> path
  }
  public.track_pageview(
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
  app_event: event.AppEvent,
  session_loaded: fn(response.Response(option.Option(SessionResponse))) -> msg,
) -> Effect(msg) {
  case app_event {
    event.NoAppEvent -> page_effect
    event.RefreshSession ->
      effect.batch([page_effect, account.get_session(session_loaded)])
  }
}
