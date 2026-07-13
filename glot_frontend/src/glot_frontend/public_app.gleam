import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/refresh_session_dto.{type RefreshSessionResponse}
import glot_core/auth/session_dto.{type SessionResponse}
import glot_core/page/site_chrome
import glot_core/page/top_bar
import glot_core/route
import glot_frontend/account_page
import glot_frontend/api
import glot_frontend/app_dialog
import glot_frontend/app_shell
import glot_frontend/browser_navigation
import glot_frontend/clock
import glot_frontend/editor_page
import glot_frontend/home_page
import glot_frontend/keyboard_shortcuts
import glot_frontend/login_page
import glot_frontend/manage_snippets_page
import glot_frontend/page_visibility
import glot_frontend/quick_action_scroll
import glot_frontend/snippets_page
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import modem
import youid/uuid

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Flags)
  Nil
}

type Model {
  Model(
    route: route.Route,
    page_model: PageModel,
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

type PageModel {
  HomePageModel(home_page.Model)
  LoginPage(login_page.Model)
  AccountPage(account_page.Model)
  ManageSnippetsPage(manage_snippets_page.Model)
  SnippetsPage(snippets_page.Model)
  EditorPage(editor_page.Model)
  EmptyPageModel
}

type QuickActionTarget {
  NavigateTo(route.Route)
  TriggerEditorAction(editor_page.Msg)
}

fn init_page(route: route.Route) -> #(PageModel, Effect(Msg)) {
  case route {
    route.Public(public_route) -> init_public_page(public_route)
    route.Account(account_route) -> init_account_page(account_route)
    route.Admin(_) | route.NotFound(_) -> #(EmptyPageModel, effect.none())
  }
}

fn init_public_page(
  public_route: route.PublicRoute,
) -> #(PageModel, Effect(Msg)) {
  case public_route {
    route.Home -> {
      let #(model, page_effect) = home_page.init()
      #(HomePageModel(model), effect.map(page_effect, HomePageMsg))
    }
    route.Login -> {
      let #(model, page_effect) = login_page.init()
      #(LoginPage(model), effect.map(page_effect, LoginPageMsg))
    }
    route.Snippets(after:, before:, username:) -> {
      let #(model, page_effect) = snippets_page.init(after:, before:, username:)
      #(SnippetsPage(model), effect.map(page_effect, SnippetsPageMsg))
    }
    route.NewSnippet(language) -> {
      let #(model, page_effect) = editor_page.init_new(language)
      #(EditorPage(model), effect.map(page_effect, EditorPageMsg))
    }
    route.Snippet(slug) -> {
      let #(model, page_effect) = editor_page.init_existing(slug)
      #(EditorPage(model), effect.map(page_effect, EditorPageMsg))
    }
  }
}

fn init_account_page(
  account_route: route.AccountRoute,
) -> #(PageModel, Effect(Msg)) {
  case account_route {
    route.AccountHome -> {
      let #(model, page_effect) = account_page.init()
      #(AccountPage(model), effect.map(page_effect, AccountPageMsg))
    }
    route.AccountSnippets(after:, before:) -> {
      let #(model, page_effect) = manage_snippets_page.init(after:, before:)
      #(
        ManageSnippetsPage(model),
        effect.map(page_effect, ManageSnippetsPageMsg),
      )
    }
  }
}

type Flags {
  Flags
}

fn init(_flags: Flags) -> #(Model, Effect(Msg)) {
  let current_route = case modem.initial_uri() {
    Ok(uri) -> route.from_uri(uri)
    Error(_) -> route.Public(route.Home)
  }
  let #(page_model, page_effect) = init_page(current_route)
  let navigation_effect =
    modem.init(fn(uri) { uri |> route.from_uri |> UserNavigatedTo })

  #(
    Model(
      route: current_route,
      page_model:,
      session: app_shell.LoadingSession,
      now: clock.now(),
      page_visible: page_visibility.document_is_visible(),
      heartbeat_in_flight: False,
      last_heartbeat_at: option.None,
      heartbeat_interval_seconds: app_shell.default_heartbeat_interval_seconds,
      quick_action_query: "",
      quick_action_selected_index: 0,
    ),
    effect.batch([
      navigation_effect,
      page_effect,
      app_shell.track_pageview(current_route, PageviewTracked),
      api.get_session(SessionLoaded),
      keyboard_shortcuts.bind(QuickActionsOpened, EditorRunShortcutPressed),
      clock.schedule_next_tick(ClockTicked),
    ]),
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
  EditorRunShortcutPressed
  HomePageMsg(home_page.Msg)
  LoginPageMsg(login_page.Msg)
  AccountPageMsg(account_page.Msg)
  ManageSnippetsPageMsg(manage_snippets_page.Msg)
  SnippetsPageMsg(snippets_page.Msg)
  EditorPageMsg(editor_page.Msg)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.page_model {
    ClockTicked(now), _ -> {
      let visible_model =
        Model(
          ..model,
          now:,
          page_visible: page_visibility.document_is_visible(),
        )
      let next_model = case
        app_shell.should_refresh_session(
          visible_model.session,
          visible_model.page_visible,
          visible_model.heartbeat_in_flight,
          visible_model.last_heartbeat_at,
          visible_model.heartbeat_interval_seconds,
          visible_model.now,
        )
      {
        True ->
          Model(
            ..visible_model,
            heartbeat_in_flight: True,
            last_heartbeat_at: option.Some(now),
          )
        False -> visible_model
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
      #(Model(..model, session:, heartbeat_in_flight: False), effect.none())
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
        "Enter" -> run_selected_quick_action(model)
        _ -> #(model, effect.none())
      }
    QuickActionsSubmitted, _ -> run_selected_quick_action(model)
    QuickActionSelected(target), _ ->
      handle_quick_action(Model(..model, quick_action_query: ""), target)

    EditorRunShortcutPressed, EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(
          page_model,
          editor_page.RunSubmitted,
          app_shell.current_user_id(model.session),
        )
      #(
        Model(..model, page_model: EditorPage(new_page_model)),
        effect.map(page_effect, EditorPageMsg),
      )
    }
    HomePageMsg(page_msg), HomePageModel(page_model) -> {
      let #(new_page_model, page_effect) =
        home_page.update(page_model, page_msg)
      #(
        Model(..model, page_model: HomePageModel(new_page_model)),
        effect.map(page_effect, HomePageMsg),
      )
    }
    LoginPageMsg(page_msg), LoginPage(page_model) -> {
      let #(new_page_model, page_effect, event) =
        login_page.update(page_model, page_msg)
      #(
        Model(..model, page_model: LoginPage(new_page_model)),
        app_shell.apply_app_event(
          effect.map(page_effect, LoginPageMsg),
          event,
          SessionLoaded,
        ),
      )
    }
    AccountPageMsg(page_msg), AccountPage(page_model) -> {
      let #(new_page_model, page_effect, event) =
        account_page.update(page_model, page_msg)
      #(
        Model(..model, page_model: AccountPage(new_page_model)),
        app_shell.apply_app_event(
          effect.map(page_effect, AccountPageMsg),
          event,
          SessionLoaded,
        ),
      )
    }
    ManageSnippetsPageMsg(page_msg), ManageSnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        manage_snippets_page.update(page_model, page_msg)
      #(
        Model(..model, page_model: ManageSnippetsPage(new_page_model)),
        effect.map(page_effect, ManageSnippetsPageMsg),
      )
    }
    SnippetsPageMsg(page_msg), SnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        snippets_page.update(page_model, page_msg)
      #(
        Model(..model, page_model: SnippetsPage(new_page_model)),
        effect.map(page_effect, SnippetsPageMsg),
      )
    }
    EditorPageMsg(page_msg), EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(
          page_model,
          page_msg,
          app_shell.current_user_id(model.session),
        )
      #(
        Model(..model, page_model: EditorPage(new_page_model)),
        effect.map(page_effect, EditorPageMsg),
      )
    }

    UserNavigatedTo(destination), _ ->
      case route.is_admin_route(destination) {
        True -> #(model, browser_navigation.load(route.to_string(destination)))
        False -> {
          let #(page_model, page_effect) = init_page(destination)
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

    _, _ -> #(model, effect.none())
  }
}

fn run_selected_quick_action(model: Model) -> #(Model, Effect(Msg)) {
  case selected_quick_action(model) {
    option.Some(top_bar.Action(msg:, ..)) ->
      update(Model(..model, quick_action_query: ""), msg)
    option.None -> #(model, effect.none())
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
  let content = case model.page_model {
    HomePageModel(page_model) ->
      home_page.view(page_model) |> element.map(HomePageMsg)
    LoginPage(page_model) ->
      login_page.view(page_model) |> element.map(LoginPageMsg)
    AccountPage(page_model) ->
      account_page.view(page_model, model.now) |> element.map(AccountPageMsg)
    ManageSnippetsPage(page_model) ->
      manage_snippets_page.view(page_model, model.now)
      |> element.map(ManageSnippetsPageMsg)
    SnippetsPage(page_model) ->
      snippets_page.view(page_model, model.now) |> element.map(SnippetsPageMsg)
    EditorPage(page_model) ->
      editor_page.view(
        page_model,
        app_shell.current_user_id(model.session),
        model.now,
      )
      |> element.map(EditorPageMsg)
    EmptyPageModel -> app_shell.not_found_view()
  }

  site_chrome.view(
    top_bar_model: top_bar_model(model),
    footer_account_route: app_shell.current_user_route(model.session),
    content:,
  )
}

fn top_bar_model(model: Model) -> top_bar.ViewModel(Msg) {
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
    sections: filtered_quick_action_sections(model),
  )
}

fn page_actions(
  page_model: PageModel,
  current_user_id: option.Option(uuid.Uuid),
) -> List(top_bar.Action(Msg)) {
  case page_model {
    EditorPage(model) ->
      list.map(editor_page.quick_actions(model, current_user_id), fn(action) {
        top_bar.map_action(action, fn(msg) {
          QuickActionSelected(TriggerEditorAction(msg))
        })
      })
    HomePageModel(_)
    | LoginPage(_)
    | AccountPage(_)
    | ManageSnippetsPage(_)
    | SnippetsPage(_)
    | EmptyPageModel -> []
  }
}

fn handle_quick_action(
  model: Model,
  target: QuickActionTarget,
) -> #(Model, Effect(Msg)) {
  let close_effect = app_dialog.close(top_bar.quick_actions_dialog_id)
  case target, model.page_model {
    NavigateTo(destination), _ -> #(
      model,
      effect.batch([close_effect, navigate_to(destination)]),
    )
    TriggerEditorAction(page_msg), EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(
          page_model,
          page_msg,
          app_shell.current_user_id(model.session),
        )
      #(
        Model(..model, page_model: EditorPage(new_page_model)),
        effect.batch([
          close_effect,
          effect.map(page_effect, EditorPageMsg),
        ]),
      )
    }
    TriggerEditorAction(_), _ -> #(model, close_effect)
  }
}

fn navigate_to(destination: route.Route) -> Effect(Msg) {
  case route.is_admin_route(destination) {
    True -> browser_navigation.load(route.to_string(destination))
    False -> {
      let #(path, query) = route.path_and_query(destination)
      modem.push(path, query, option.None)
    }
  }
}

fn filtered_quick_action_sections(model: Model) -> List(top_bar.Section(Msg)) {
  let query = model.quick_action_query |> string.trim |> string.lowercase
  case model.session, model.route, model.page_model, query {
    app_shell.LoadingSession, route.Public(route.Home), HomePageModel(_), "" ->
      top_bar.default_quick_action_sections(fn(destination) {
        QuickActionSelected(NavigateTo(destination))
      })
    _, _, _, _ ->
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
          #(
            1,
            top_bar.Section(
              title: "Page actions",
              actions: page_actions(
                model.page_model,
                app_shell.current_user_id(model.session),
              ),
            ),
          ),
          #(
            2,
            top_bar.Section(
              title: "Languages",
              actions: top_bar.language_actions(
                query:,
                on_navigate: fn(destination) {
                  QuickActionSelected(NavigateTo(destination))
                },
              ),
            ),
          ),
        ],
        query,
      )
  }
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

fn move_and_scroll_quick_action_selection(
  model: Model,
  delta: Int,
) -> #(Model, Effect(Msg)) {
  let selected_index =
    top_bar.wrapped_selected_index(
      filtered_quick_action_sections(model),
      model.quick_action_selected_index,
      delta,
    )
  let next_model = Model(..model, quick_action_selected_index: selected_index)
  #(
    next_model,
    quick_action_scroll.ensure_visible(normalized_selected_index(next_model)),
  )
}
