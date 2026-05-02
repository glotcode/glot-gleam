import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/session_dto
import glot_core/page/site_chrome
import glot_core/page/top_bar
import glot_core/pageview_dto
import glot_core/route
import glot_frontend/account_page
import glot_frontend/api
import glot_frontend/app_dialog
import glot_frontend/app_event
import glot_frontend/clock
import glot_frontend/editor_page
import glot_frontend/home_page
import glot_frontend/keyboard_shortcuts
import glot_frontend/login_page
import glot_frontend/manage_snippets_page
import glot_frontend/quick_action_scroll
import glot_frontend/snippets_page
import glot_frontend/string_helpers
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
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
    session: SessionState,
    now: Timestamp,
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

type SessionState {
  LoadingSession
  AnonymousSession
  AuthenticatedSession(session_dto.SessionResponse)
  SessionError
}

type QuickActionTarget {
  NavigateTo(route.Route)
  TriggerEditorAction(editor_page.Msg)
}

fn init_page(route: route.Route) -> #(PageModel, Effect(Msg)) {
  case route {
    route.Home -> {
      let #(m, eff) = home_page.init()
      #(HomePageModel(m), effect.map(eff, HomePageMsg))
    }

    route.Login -> {
      let #(m, eff) = login_page.init()
      #(LoginPage(m), effect.map(eff, LoginPageMsg))
    }

    route.Account -> {
      let #(m, eff) = account_page.init()
      #(AccountPage(m), effect.map(eff, AccountPageMsg))
    }

    route.AccountSnippets(after:, before:) -> {
      let #(m, eff) = manage_snippets_page.init(after:, before:)
      #(ManageSnippetsPage(m), effect.map(eff, ManageSnippetsPageMsg))
    }

    route.Snippets(after:, before:, username:) -> {
      let #(m, eff) = snippets_page.init(after:, before:, username:)
      #(SnippetsPage(m), effect.map(eff, SnippetsPageMsg))
    }

    route.NewSnippet(language) -> {
      let #(m, eff) = editor_page.init_new(language)
      #(EditorPage(m), effect.map(eff, EditorPageMsg))
    }

    route.Snippet(slug) -> {
      let #(m, eff) = editor_page.init_existing(slug)
      #(EditorPage(m), effect.map(eff, EditorPageMsg))
    }

    route.NotFound(_) -> #(EmptyPageModel, effect.none())
  }
}

type Flags {
  Flags
}

fn init(_flags: Flags) -> #(Model, Effect(Msg)) {
  let r = case modem.initial_uri() {
    Ok(uri) -> route.from_uri(uri)
    Error(_) -> route.Home
  }

  let #(page_model, page_effect) = init_page(r)

  let eff =
    modem.init(fn(uri) {
      uri
      |> route.from_uri
      |> UserNavigatedTo
    })

  let session_effect = api.get_session(SessionLoaded)
  let shortcut_effect =
    keyboard_shortcuts.bind(QuickActionsOpened, EditorRunShortcutPressed)
  let effects =
    effect.batch([
      eff,
      page_effect,
      session_effect,
      shortcut_effect,
      clock.schedule_next_minute(MinuteTicked),
    ])

  #(
    Model(
      route: r,
      page_model: page_model,
      session: LoadingSession,
      now: clock.now(),
      quick_action_query: "",
      quick_action_selected_index: 0,
    ),
    effects,
  )
}

type Msg {
  UserNavigatedTo(route: route.Route)
  PageviewTracked(api.ApiResponse(Nil))
  SessionLoaded(api.ApiResponse(option.Option(session_dto.SessionResponse)))
  MinuteTicked(Timestamp)
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
    MinuteTicked(now), _ -> #(
      Model(..model, now: now),
      clock.schedule_next_minute(MinuteTicked),
    )

    SessionLoaded(result), _ -> {
      let session = case result {
        api.ApiSuccess(option.Some(session)) -> AuthenticatedSession(session)
        api.ApiSuccess(option.None) -> AnonymousSession
        api.ApiFailure(_) | api.HttpFailure(_) -> SessionError
      }

      #(Model(..model, session: session), effect.none())
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

    EditorRunShortcutPressed, EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(
          page_model,
          editor_page.RunSubmitted,
          current_user_id(model.session),
        )
      let new_model = Model(..model, page_model: EditorPage(new_page_model))
      #(new_model, effect.map(page_effect, EditorPageMsg))
    }

    HomePageMsg(page_msg), HomePageModel(page_model) -> {
      let #(new_page_model, page_effect) =
        home_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: HomePageModel(new_page_model))
      #(new_model, effect.map(page_effect, HomePageMsg))
    }

    LoginPageMsg(page_msg), LoginPage(page_model) -> {
      let #(new_page_model, page_effect, event) =
        login_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: LoginPage(new_page_model))
      let mapped_effect = effect.map(page_effect, LoginPageMsg)
      #(new_model, apply_app_event(mapped_effect, event))
    }

    AccountPageMsg(page_msg), AccountPage(page_model) -> {
      let #(new_page_model, page_effect, event) =
        account_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: AccountPage(new_page_model))
      let mapped_effect = effect.map(page_effect, AccountPageMsg)
      #(new_model, apply_app_event(mapped_effect, event))
    }

    ManageSnippetsPageMsg(page_msg), ManageSnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        manage_snippets_page.update(page_model, page_msg)
      let new_model =
        Model(..model, page_model: ManageSnippetsPage(new_page_model))
      #(new_model, effect.map(page_effect, ManageSnippetsPageMsg))
    }

    SnippetsPageMsg(page_msg), SnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        snippets_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: SnippetsPage(new_page_model))
      #(new_model, effect.map(page_effect, SnippetsPageMsg))
    }

    EditorPageMsg(page_msg), EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(page_model, page_msg, current_user_id(model.session))
      let new_model = Model(..model, page_model: EditorPage(new_page_model))
      #(new_model, effect.map(page_effect, EditorPageMsg))
    }

    UserNavigatedTo(route:), _ -> {
      let #(page_model, page_effect) = init_page(route)
      #(
        Model(
          ..model,
          route:,
          page_model:,
          quick_action_query: "",
          quick_action_selected_index: 0,
        ),
        effect.batch([
          app_dialog.close(top_bar.quick_actions_dialog_id),
          page_effect,
          track_pageview(route),
        ]),
      )
    }

    _, _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  let page_content =
    case model.page_model {
      EmptyPageModel -> {
        not_found_view()
      }

      HomePageModel(page_model) -> {
        let elem = home_page.view(page_model)
        element.map(elem, HomePageMsg)
      }

      LoginPage(page_model) -> {
        let elem = login_page.view(page_model)
        element.map(elem, LoginPageMsg)
      }

      AccountPage(page_model) -> {
        let elem = account_page.view(page_model, model.now)
        element.map(elem, AccountPageMsg)
      }

      ManageSnippetsPage(page_model) -> {
        let elem = manage_snippets_page.view(page_model, model.now)
        element.map(elem, ManageSnippetsPageMsg)
      }

      SnippetsPage(page_model) -> {
        let elem = snippets_page.view(page_model, model.now)
        element.map(elem, SnippetsPageMsg)
      }

      EditorPage(page_model) -> {
        let elem =
          editor_page.view(page_model, current_user_id(model.session), model.now)
        element.map(elem, EditorPageMsg)
      }
    }

  site_chrome.view(
    top_bar_model: top_bar_model(model),
    footer_account_route: current_user_route(model.session),
    content: page_content,
  )
}

fn current_user_id(session: SessionState) -> option.Option(uuid.Uuid) {
  case session {
    AuthenticatedSession(session) -> option.Some(session.user.id)
    LoadingSession | AnonymousSession | SessionError -> option.None
  }
}

fn current_user_label(session: SessionState) -> String {
  case session {
    AuthenticatedSession(session) ->
      case string.length(session.user.username) > 20 {
        True -> string_helpers.truncate_stem_middle(session.user.username, 20)
        False -> session.user.username
      }

    LoadingSession | AnonymousSession | SessionError -> "Account"
  }
}

fn current_user_route(session: SessionState) -> route.Route {
  case session {
    AuthenticatedSession(_) | LoadingSession -> route.Account
    AnonymousSession | SessionError -> route.Login
  }
}

fn top_bar_model(model: Model) -> top_bar.ViewModel(Msg) {
  let sections = filtered_quick_action_sections(model)

  top_bar.ViewModel(
    current_user_label: current_user_label(model.session),
    account_route: current_user_route(model.session),
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

fn navigation_actions(
  session: SessionState,
  current_route: route.Route,
  query: String,
) -> List(top_bar.Action(Msg)) {
  let navigation_state = case session {
    AuthenticatedSession(_) | LoadingSession -> top_bar.CanManageAccount
    AnonymousSession | SessionError -> top_bar.NeedsLogin
  }

  top_bar.navigation_actions(
    navigation_state:,
    current_route:,
    query:,
    on_navigate: fn(destination) {
      QuickActionSelected(NavigateTo(destination))
    },
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

  case target, model.page_model {
    NavigateTo(route), _ -> #(
      model,
      effect.batch([close_effect, navigate_to(route)]),
    )

    TriggerEditorAction(page_msg), EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(page_model, page_msg, current_user_id(model.session))
      let next_model = Model(..model, page_model: EditorPage(new_page_model))
      #(
        next_model,
        effect.batch([close_effect, effect.map(page_effect, EditorPageMsg)]),
      )
    }

    TriggerEditorAction(_), _ -> #(model, close_effect)
  }
}

fn navigate_to(route: route.Route) -> Effect(Msg) {
  let #(path, query) = route.path_and_query(route)
  modem.push(path, query, option.None)
}

fn track_pageview(route: route.Route) -> Effect(Msg) {
  let #(path, query) = route.path_and_query(route)
  let full_path = case query {
    option.Some(query) -> path <> "?" <> query
    option.None -> path
  }

  api.track_pageview(
    pageview_dto.PageviewRequest(
      id: uuid.v7(),
      route: route.name(route),
      path: full_path,
    ),
    PageviewTracked,
  )
}

fn filtered_quick_action_sections(model: Model) -> List(top_bar.Section(Msg)) {
  let query = model.quick_action_query |> string.trim |> string.lowercase
  let uses_default_quick_action_sections = case
    model.session,
    model.route,
    model.page_model,
    query
  {
    LoadingSession, route.Home, HomePageModel(_), "" -> True
    _, _, _, _ -> False
  }

  case uses_default_quick_action_sections {
    True ->
      top_bar.default_quick_action_sections(fn(destination) {
        QuickActionSelected(NavigateTo(destination))
      })
    False -> filtered_quick_action_sections_for_state(model, query)
  }
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
          actions: navigation_actions(model.session, model.route, query),
        ),
      ),
      #(
        1,
        top_bar.Section(
          title: "Page actions",
          actions: page_actions(
            model.page_model,
            current_user_id(model.session),
          ),
        ),
      ),
      #(
        2,
        top_bar.Section(
          title: "Languages",
          actions: language_actions(query),
        ),
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

fn apply_app_event(
  page_effect: Effect(Msg),
  event: app_event.AppEvent,
) -> Effect(Msg) {
  case event {
    app_event.NoAppEvent -> page_effect
    app_event.RefreshSession ->
      effect.batch([page_effect, api.get_session(SessionLoaded)])
  }
}

fn not_found_view() -> Element(Msg) {
  html.div([], [
    html.h2([], [html.text("404 Not Found")]),
  ])
}
