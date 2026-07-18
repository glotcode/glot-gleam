import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/refresh_session_dto.{type RefreshSessionResponse}
import glot_core/auth/session_dto.{type SessionResponse}
import glot_core/page/site_chrome
import glot_core/page/top_bar
import glot_core/route
import glot_frontend/admin_breadcrumbs
import glot_frontend/admin_pages
import glot_frontend/api
import glot_frontend/app_dialog
import glot_frontend/app_shell
import glot_frontend/browser_navigation
import glot_frontend/clock
import glot_frontend/keyboard_shortcuts
import glot_frontend/page_visibility
import glot_frontend/quick_action_scroll
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import modem

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Flags)

  Nil
}

type Model {
  Model(
    route: route.Route,
    page_model: admin_pages.Model,
    session: app_shell.SessionState,
    now: Timestamp,
    page_visible: Bool,
    heartbeat_in_flight: Bool,
    last_heartbeat_at: option.Option(Timestamp),
    heartbeat_interval_seconds: Int,
    quick_action_query: String,
    quick_action_selected_index: Int,
  )
}

type QuickActionTarget {
  NavigateTo(route.Route)
}

fn init_page(
  route: route.Route,
  session: app_shell.SessionState,
) -> #(admin_pages.Model, Effect(Msg)) {
  case route {
    route.Admin(admin_route) -> {
      let #(page_model, page_effect) =
        admin_pages.init(admin_route, app_shell.is_admin(session))
      #(page_model, effect.map(page_effect, AdminPagesMsg))
    }
    route.Public(_) | route.Account(_) | route.NotFound(_) -> #(
      admin_pages.empty(),
      effect.none(),
    )
  }
}

type Flags {
  Flags
}

fn init(_flags: Flags) -> #(Model, Effect(Msg)) {
  let r = case modem.initial_uri() {
    Ok(uri) -> route.from_uri(uri)
    Error(_) -> route.Public(route.Home)
  }

  let #(page_model, page_effect) = init_page(r, app_shell.LoadingSession)

  let eff =
    modem.init(fn(uri) {
      uri
      |> route.from_uri
      |> UserNavigatedTo
    })

  let session_effect = api.get_session(SessionLoaded)
  let shortcut_effect =
    keyboard_shortcuts.bind(QuickActionsOpened, IgnoredEditorRunShortcut)
  let effects =
    effect.batch([
      eff,
      page_effect,
      app_shell.track_pageview(r, PageviewTracked),
      session_effect,
      shortcut_effect,
      clock.schedule_next_tick(ClockTicked),
    ])

  #(
    Model(
      route: r,
      page_model: page_model,
      session: app_shell.LoadingSession,
      now: clock.now(),
      page_visible: page_visibility.document_is_visible(),
      heartbeat_in_flight: False,
      last_heartbeat_at: option.None,
      heartbeat_interval_seconds: app_shell.default_heartbeat_interval_seconds,
      quick_action_query: "",
      quick_action_selected_index: 0,
    ),
    effects,
  )
}

type Msg {
  UserNavigatedTo(route: route.Route)
  PageviewTracked(api.ApiResponse(Nil))
  SessionLoaded(api.ApiResponse(option.Option(SessionResponse)))
  SessionRefreshed(api.ApiResponse(RefreshSessionResponse))
  ClockTicked(Timestamp)
  QuickActionsOpened
  QuickActionsDismissed
  QuickActionsClosed
  QuickActionsQueryChanged(String)
  QuickActionsKeyPressed(String)
  QuickActionsSubmitted
  QuickActionSelected(QuickActionTarget)
  IgnoredEditorRunShortcut
  AdminPagesMsg(admin_pages.Msg)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.page_model {
    ClockTicked(now), _ -> {
      let should_start_heartbeat =
        app_shell.should_refresh_session(
          model.session,
          page_visibility.document_is_visible(),
          model.heartbeat_in_flight,
          model.last_heartbeat_at,
          model.heartbeat_interval_seconds,
          now,
        )
      let next_model = case should_start_heartbeat {
        True ->
          Model(
            ..model,
            now: now,
            page_visible: page_visibility.document_is_visible(),
            heartbeat_in_flight: True,
            last_heartbeat_at: option.Some(now),
          )
        False ->
          Model(
            ..model,
            now: now,
            page_visible: page_visibility.document_is_visible(),
          )
      }
      #(
        next_model,
        effect.batch([
          clock.schedule_next_tick(ClockTicked),
          heartbeat_effect(next_model),
        ]),
      )
    }

    SessionLoaded(result), _ -> {
      let session = app_shell.session_from_response(result)

      let next_model =
        Model(..model, session: session, heartbeat_in_flight: False)

      case route.is_admin_route(model.route) {
        True ->
          case app_shell.is_admin(session) {
            True -> {
              let #(page_model, page_effect) =
                admin_pages.session_loaded(next_model.page_model)
              #(
                Model(..next_model, page_model: page_model),
                effect.map(page_effect, AdminPagesMsg),
              )
            }
            False -> #(next_model, replace_route(admin_fallback_route(session)))
          }
        False -> #(next_model, effect.none())
      }
    }

    SessionRefreshed(result), _ ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            heartbeat_in_flight: False,
            heartbeat_interval_seconds: response.next_heartbeat_in_seconds,
          ),
          effect.none(),
        )
        api.ApiFailure(_) | api.HttpFailure(_) -> #(
          Model(..model, heartbeat_in_flight: False),
          api.get_session(SessionLoaded),
        )
      }

    PageviewTracked(_), _ -> #(model, effect.none())

    QuickActionsOpened, _ -> #(
      Model(..model, quick_action_query: "", quick_action_selected_index: 0),
      app_dialog.open(top_bar.quick_actions_dialog_id),
    )

    QuickActionsDismissed, _ -> #(
      Model(..model, quick_action_query: "", quick_action_selected_index: 0),
      app_dialog.close(top_bar.quick_actions_dialog_id),
    )

    QuickActionsClosed, _ -> #(
      Model(..model, quick_action_query: "", quick_action_selected_index: 0),
      app_dialog.close(top_bar.quick_actions_dialog_id),
    )

    QuickActionsQueryChanged(query), _ -> #(
      Model(..model, quick_action_query: query, quick_action_selected_index: 0),
      effect.none(),
    )

    QuickActionsKeyPressed(key), _ ->
      case key {
        "ArrowDown" -> move_and_scroll_quick_action_selection(model, 1)
        "ArrowUp" -> move_and_scroll_quick_action_selection(model, -1)
        "Enter" ->
          case selected_quick_action(model) {
            option.Some(action) ->
              case action {
                top_bar.Action(msg:, ..) ->
                  update(Model(..model, quick_action_query: ""), msg)
              }
            option.None -> #(model, effect.none())
          }
        _ -> #(model, effect.none())
      }

    QuickActionsSubmitted, _ ->
      case selected_quick_action(model) {
        option.Some(action) ->
          case action {
            top_bar.Action(msg:, ..) ->
              update(Model(..model, quick_action_query: ""), msg)
          }

        option.None -> #(model, effect.none())
      }

    QuickActionSelected(target), _ ->
      handle_quick_action(Model(..model, quick_action_query: ""), target)

    AdminPagesMsg(page_msg), _ -> {
      let #(page_model, page_effect) =
        admin_pages.update(model.page_model, page_msg)
      #(
        Model(..model, page_model: page_model),
        effect.map(page_effect, AdminPagesMsg),
      )
    }

    UserNavigatedTo(route:), _ -> {
      case route.is_admin_route(model.route), route.is_admin_route(route) {
        True, False -> #(model, browser_navigation.load(route.to_string(route)))
        _, _ -> {
          let destination = authorized_route(route, model.session)
          let #(page_model, page_effect) = init_page(destination, model.session)
          #(
            Model(
              ..model,
              route: destination,
              page_model:,
              quick_action_query: "",
              quick_action_selected_index: 0,
            ),
            effect.batch([
              app_dialog.close(top_bar.quick_actions_dialog_id),
              page_effect,
              app_shell.track_pageview(destination, PageviewTracked),
            ]),
          )
        }
      }
    }

    _, _ -> #(model, effect.none())
  }
}

fn heartbeat_effect(model: Model) -> Effect(Msg) {
  case
    app_shell.should_refresh_session(
      model.session,
      model.page_visible,
      model.heartbeat_in_flight,
      model.last_heartbeat_at,
      model.heartbeat_interval_seconds,
      model.now,
    )
  {
    True -> api.refresh_session(SessionRefreshed)
    False -> effect.none()
  }
}

fn view(model: Model) -> Element(Msg) {
  case app_shell.is_admin(model.session) {
    True -> admin_view(model)
    False -> element.none()
  }
}

fn admin_view(model: Model) -> Element(Msg) {
  let page_content =
    admin_pages.view(model.page_model, model.now)
    |> element.map(AdminPagesMsg)

  let content = case admin_breadcrumbs.is_admin_route(model.route) {
    True -> admin_breadcrumbs.wrap(model.route, page_content)
    False -> page_content
  }

  site_chrome.view(
    top_bar_model: top_bar_model(model),
    footer_account_route: app_shell.current_user_route(model.session),
    content: content,
  )
}

fn top_bar_model(model: Model) -> top_bar.ViewModel(Msg) {
  let sections = filtered_quick_action_sections(model)

  top_bar.ViewModel(
    current_user_label: app_shell.current_user_label(model.session),
    account_route: app_shell.current_user_route(model.session),
    search_query: model.quick_action_query,
    selected_index: normalized_selected_index(model),
    open_msg: QuickActionsOpened,
    close_msg: QuickActionsDismissed,
    search_changed: QuickActionsQueryChanged,
    keydown: QuickActionsKeyPressed,
    submit_msg: QuickActionsSubmitted,
    sections: sections,
  )
}

fn language_actions(query: String) -> List(top_bar.Action(Msg)) {
  top_bar.language_actions(query:, on_navigate: fn(destination) {
    QuickActionSelected(NavigateTo(destination))
  })
}

fn handle_quick_action(
  model: Model,
  target: QuickActionTarget,
) -> #(Model, Effect(Msg)) {
  let close_effect = app_dialog.close(top_bar.quick_actions_dialog_id)

  case target {
    NavigateTo(destination) -> #(
      model,
      effect.batch([close_effect, navigate_to(destination)]),
    )
  }
}

fn navigate_to(destination: route.Route) -> Effect(Msg) {
  case route.is_admin_route(destination) {
    True -> {
      let #(path, query) = route.path_and_query(destination)
      modem.push(path, query, option.None)
    }
    False -> browser_navigation.load(route.to_string(destination))
  }
}

fn filtered_quick_action_sections(model: Model) -> List(top_bar.Section(Msg)) {
  let query = model.quick_action_query |> string.trim |> string.lowercase
  filtered_quick_action_sections_for_state(model, query)
}

fn filtered_quick_action_sections_for_state(
  model: Model,
  query: String,
) -> List(top_bar.Section(Msg)) {
  top_bar.filter_and_rank_sections(
    [
      #(
        0,
        top_bar.Section(
          title: "Navigation",
          actions: app_shell.navigation_actions(
            model.session,
            model.route,
            query,
            fn(destination) { QuickActionSelected(NavigateTo(destination)) },
          ),
        ),
      ),
      #(1, top_bar.Section(title: "Page actions", actions: [])),
      #(
        2,
        top_bar.Section(title: "Languages", actions: language_actions(query)),
      ),
    ],
    query,
  )
}

fn selected_quick_action(model: Model) -> option.Option(top_bar.Action(Msg)) {
  filtered_quick_action_sections(model)
  |> top_bar.flattened_actions
  |> top_bar.action_at(normalized_selected_index(model))
}

fn normalized_selected_index(model: Model) -> Int {
  top_bar.normalized_selected_index(
    filtered_quick_action_sections(model),
    model.quick_action_selected_index,
  )
}

fn move_quick_action_selection(model: Model, delta: Int) -> Model {
  let wrapped =
    top_bar.wrapped_selected_index(
      filtered_quick_action_sections(model),
      model.quick_action_selected_index,
      delta,
    )
  Model(..model, quick_action_selected_index: wrapped)
}

fn move_and_scroll_quick_action_selection(
  model: Model,
  delta: Int,
) -> #(Model, Effect(Msg)) {
  let next_model = move_quick_action_selection(model, delta)
  let selected_index = normalized_selected_index(next_model)
  #(next_model, quick_action_scroll.ensure_visible(selected_index))
}

fn authorized_route(
  target_route: route.Route,
  session: app_shell.SessionState,
) -> route.Route {
  case route.is_admin_route(target_route) {
    True ->
      case app_shell.is_admin(session) {
        True -> target_route
        False -> admin_fallback_route(session)
      }
    False -> target_route
  }
}

fn admin_fallback_route(session: app_shell.SessionState) -> route.Route {
  case session {
    app_shell.AnonymousSession | app_shell.SessionError ->
      route.Public(route.Login)
    app_shell.AuthenticatedSession(_) | app_shell.LoadingSession ->
      route.Public(route.Home)
  }
}

fn replace_route(target_route: route.Route) -> Effect(Msg) {
  let #(path, query) = route.path_and_query(target_route)
  modem.replace(path, query, option.None)
}
