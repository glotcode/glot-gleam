import gleam/option.{type Option}
import gleam/string
import glot_core/route
import glot_frontend/app/quick_actions
import glot_frontend/app/runtime
import glot_web/page/top_bar

pub type Messages(msg) {
  Messages(
    open: msg,
    close: msg,
    query_changed: fn(String) -> msg,
    key_pressed: fn(String) -> msg,
    submitted: msg,
  )
}

pub fn view_model(
  session: runtime.SessionState,
  state: quick_actions.Model,
  sections: List(top_bar.Section(action)),
  messages: Messages(msg),
  on_action: fn(action) -> msg,
) -> top_bar.ViewModel(msg) {
  top_bar.ViewModel(
    current_user_label: runtime.current_user_label(session),
    account_route: runtime.current_user_route(session),
    search_query: state.query,
    selected_index: quick_actions.normalized_index_for_sections(state, sections),
    open_msg: messages.open,
    close_msg: messages.close,
    search_changed: messages.query_changed,
    keydown: messages.key_pressed,
    submit_msg: messages.submitted,
    sections: quick_actions.map_sections(sections, on_action),
  )
}

pub fn sections(
  session: runtime.SessionState,
  current_route: route.Route,
  query: String,
  page_actions: List(top_bar.Action(msg)),
  on_navigate: fn(route.Route) -> msg,
) -> List(top_bar.Section(msg)) {
  let normalized_query = query |> string.trim |> string.lowercase
  case session, current_route, normalized_query {
    runtime.LoadingSession, route.Public(route.Home), "" ->
      top_bar.default_quick_action_sections(on_navigate)
    _, _, _ ->
      top_bar.filter_and_rank_sections(
        [
          #(
            0,
            top_bar.Section(
              title: "Navigation",
              actions: runtime.navigation_actions(
                session,
                current_route,
                normalized_query,
                on_navigate,
              ),
            ),
          ),
          #(1, top_bar.Section(title: "Page actions", actions: page_actions)),
          #(
            2,
            top_bar.Section(
              title: "Languages",
              actions: top_bar.language_actions(
                query: normalized_query,
                on_navigate:,
              ),
            ),
          ),
        ],
        normalized_query,
      )
  }
}

pub fn selected(
  state: quick_actions.Model,
  sections: List(top_bar.Section(msg)),
) -> Option(top_bar.Action(msg)) {
  quick_actions.selected_action(state, sections)
}

pub fn move(
  state: quick_actions.Model,
  sections: List(top_bar.Section(msg)),
  delta: Int,
) -> #(quick_actions.Model, Int) {
  let next = quick_actions.move_for_sections(state, sections, delta)
  #(next, quick_actions.normalized_index_for_sections(next, sections))
}
