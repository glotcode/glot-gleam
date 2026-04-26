import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import glot_core/auth/session_dto
import glot_core/language
import glot_frontend/account_page
import glot_frontend/api
import glot_frontend/app_dialog
import glot_frontend/app_event
import glot_frontend/editor_page
import glot_frontend/home_page
import glot_frontend/keyboard_shortcuts
import glot_frontend/login_page
import glot_frontend/manage_snippets_page
import glot_frontend/quick_action_scroll
import glot_frontend/route
import glot_frontend/snippets_page
import glot_frontend/string_helpers
import glot_frontend/top_bar
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

const initial_language_actions = [
  language.Python,
  language.TypeScript,
  language.C,
  language.Rust,
  language.Java,
]

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
  let shortcut_effect = keyboard_shortcuts.bind(QuickActionsOpened)
  let effects =
    effect.batch([eff, page_effect, session_effect, shortcut_effect])

  #(
    Model(
      route: r,
      page_model: page_model,
      session: LoadingSession,
      quick_action_query: "",
      quick_action_selected_index: 0,
    ),
    effects,
  )
}

type Msg {
  UserNavigatedTo(route: route.Route)
  SessionLoaded(api.ApiResponse(option.Option(session_dto.SessionResponse)))
  QuickActionsOpened
  QuickActionsDismissed
  QuickActionsClosed
  QuickActionsQueryChanged(String)
  QuickActionsKeyPressed(String)
  QuickActionsSubmitted
  QuickActionSelected(QuickActionTarget)
  HomePageMsg(home_page.Msg)
  LoginPageMsg(login_page.Msg)
  AccountPageMsg(account_page.Msg)
  ManageSnippetsPageMsg(manage_snippets_page.Msg)
  SnippetsPageMsg(snippets_page.Msg)
  EditorPageMsg(editor_page.Msg)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.page_model {
    SessionLoaded(result), _ -> {
      let session = case result {
        api.ApiSuccess(option.Some(session)) -> AuthenticatedSession(session)
        api.ApiSuccess(option.None) -> AnonymousSession
        api.ApiFailure(_) | api.HttpFailure(_) -> SessionError
      }

      #(Model(..model, session: session), effect.none())
    }

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
        ]),
      )
    }

    _, _ -> #(model, effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [
    top_bar.view(top_bar_model(model)),
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
        let elem = account_page.view(page_model)
        element.map(elem, AccountPageMsg)
      }

      ManageSnippetsPage(page_model) -> {
        let elem = manage_snippets_page.view(page_model)
        element.map(elem, ManageSnippetsPageMsg)
      }

      SnippetsPage(page_model) -> {
        let elem = snippets_page.view(page_model)
        element.map(elem, SnippetsPageMsg)
      }

      EditorPage(page_model) -> {
        let elem = editor_page.view(page_model, current_user_id(model.session))
        element.map(elem, EditorPageMsg)
      }
    },
  ])
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
  let shared = [
    top_bar.Action(
      label: "Home",
      description: "Go to the front page.",
      msg: QuickActionSelected(NavigateTo(route.Home)),
    ),
    top_bar.Action(
      label: "Public snippets",
      description: "Browse public code snippets.",
      msg: QuickActionSelected(
        NavigateTo(route.Snippets(option.None, option.None, option.None)),
      ),
    ),
  ]

  case session {
    AuthenticatedSession(_) | LoadingSession ->
      list.append(shared, [
        top_bar.Action(
          label: "My snippets",
          description: "Manage snippets in your account.",
          msg: QuickActionSelected(
            NavigateTo(route.AccountSnippets(option.None, option.None)),
          ),
        ),
        top_bar.Action(
          label: "Account",
          description: "Open your account settings.",
          msg: QuickActionSelected(NavigateTo(route.Account)),
        ),
      ])

    AnonymousSession | SessionError ->
      case query == "" {
        True ->
          list.append(shared, [
            top_bar.Action(
              label: "Login",
              description: "Sign in to save and manage snippets.",
              msg: QuickActionSelected(NavigateTo(route.Login)),
            ),
          ])
        False ->
          list.append(shared, [
            top_bar.Action(
              label: "Login",
              description: "Sign in to save and manage snippets.",
              msg: QuickActionSelected(NavigateTo(route.Login)),
            ),
            top_bar.Action(
              label: "Register",
              description: "Create an account or sign in with email.",
              msg: QuickActionSelected(NavigateTo(route.Login)),
            ),
          ])
      }
  }
  |> list.filter(fn(action) {
    !is_current_navigation_action(action, current_route)
  })
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
  let normalized_query = query |> string.trim |> string.lowercase

  let languages = case normalized_query == "" {
    True -> initial_language_actions
    False ->
      language.list()
      |> list.filter(fn(lang) {
        let name = language.name(lang) |> string.lowercase
        let slug = language.to_string(lang) |> string.lowercase
        string.contains(name, normalized_query)
        || string.contains(slug, normalized_query)
      })
  }

  list.map(languages, fn(lang) {
    let name = language.name(lang)
    top_bar.Action(
      label: name,
      description: "Create a new " <> name <> " snippet.",
      msg: QuickActionSelected(
        NavigateTo(route.NewSnippet(language.to_string(lang))),
      ),
    )
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

fn filtered_quick_action_sections(model: Model) -> List(top_bar.Section(Msg)) {
  let query = model.quick_action_query |> string.trim |> string.lowercase
  let sections =
    [
      #(
        0,
        top_bar.Section(
          title: "Navigation",
          actions: navigation_actions(model.session, model.route, query)
            |> list.filter(action_matches(_, query)),
        ),
      ),
      #(
        1,
        top_bar.Section(
          title: "Page actions",
          actions: page_actions(
            model.page_model,
            current_user_id(model.session),
          )
            |> list.filter(action_matches(_, query)),
        ),
      ),
      #(
        2,
        top_bar.Section(
          title: "Languages",
          actions: language_actions(query)
            |> list.filter(action_matches(_, query)),
        ),
      ),
    ]
    |> list.filter(fn(section) { section_has_actions(section.1) })

  case query == "" {
    True -> list.map(sections, fn(section) { section.1 })
    False ->
      sections
      |> list.sort(by: compare_sections(query))
      |> list.map(fn(section) {
        section.1
        |> sort_section_actions(query)
        |> cap_section_actions(5)
      })
  }
}

fn action_matches(action: top_bar.Action(Msg), query: String) -> Bool {
  case query == "" {
    True -> True
    False ->
      case action {
        top_bar.Action(label:, description:, ..) -> {
          let label = label |> string.lowercase
          let description = description |> string.lowercase
          string.contains(label, query) || string.contains(description, query)
        }
      }
  }
}

fn is_current_navigation_action(
  action: top_bar.Action(Msg),
  current_route: route.Route,
) -> Bool {
  case action {
    top_bar.Action(msg: QuickActionSelected(NavigateTo(target_route)), ..) ->
      route.path_and_query(target_route) == route.path_and_query(current_route)
    _ -> False
  }
}

fn selected_quick_action(model: Model) -> option.Option(top_bar.Action(Msg)) {
  filtered_quick_action_sections(model)
  |> flattened_quick_actions
  |> action_at(normalized_selected_index(model))
}

fn compare_sections(
  query: String,
) -> fn(#(Int, top_bar.Section(Msg)), #(Int, top_bar.Section(Msg))) ->
  order.Order {
  fn(left: #(Int, top_bar.Section(Msg)), right: #(Int, top_bar.Section(Msg))) {
    let left_score = section_score(left.1, query)
    let right_score = section_score(right.1, query)

    order.break_tie(
      in: int.compare(right_score, left_score),
      with: int.compare(left.0, right.0),
    )
  }
}

fn section_score(section: top_bar.Section(Msg), query: String) -> Int {
  case section {
    top_bar.Section(actions:, ..) ->
      actions
      |> list.map(action_score(_, query))
      |> list.fold(0, fn(best, score) {
        case score > best {
          True -> score
          False -> best
        }
      })
  }
}

fn action_score(action: top_bar.Action(Msg), query: String) -> Int {
  case action {
    top_bar.Action(label:, description:, ..) -> {
      let normalized_label = string.lowercase(label)
      let normalized_description = string.lowercase(description)

      case normalized_label == query {
        True -> 100
        False ->
          case string.starts_with(normalized_label, query) {
            True -> 80
            False ->
              case string.contains(normalized_label, query) {
                True -> 60
                False ->
                  case string.starts_with(normalized_description, query) {
                    True -> 40
                    False ->
                      case string.contains(normalized_description, query) {
                        True -> 20
                        False -> 0
                      }
                  }
              }
          }
      }
    }
  }
}

fn section_has_actions(section: top_bar.Section(Msg)) -> Bool {
  case section {
    top_bar.Section(actions: [], ..) -> False
    top_bar.Section(actions: _, ..) -> True
  }
}

fn flattened_quick_actions(
  sections: List(top_bar.Section(Msg)),
) -> List(top_bar.Action(Msg)) {
  case sections {
    [] -> []
    [top_bar.Section(actions:, ..), ..rest] ->
      list.append(actions, flattened_quick_actions(rest))
  }
}

fn normalized_selected_index(model: Model) -> Int {
  let count =
    filtered_quick_action_sections(model)
    |> flattened_quick_actions
    |> list.length

  case count <= 0 {
    True -> 0
    False -> int.clamp(model.quick_action_selected_index, 0, count - 1)
  }
}

fn move_quick_action_selection(model: Model, delta: Int) -> Model {
  let count =
    filtered_quick_action_sections(model)
    |> flattened_quick_actions
    |> list.length

  case count <= 0 {
    True -> Model(..model, quick_action_selected_index: 0)
    False -> {
      let current = normalized_selected_index(model)
      let next = current + delta
      let wrapped = case next < 0 {
        True -> count - 1
        False ->
          case next >= count {
            True -> 0
            False -> next
          }
      }

      Model(..model, quick_action_selected_index: wrapped)
    }
  }
}

fn move_and_scroll_quick_action_selection(
  model: Model,
  delta: Int,
) -> #(Model, Effect(Msg)) {
  let next_model = move_quick_action_selection(model, delta)
  let selected_index = normalized_selected_index(next_model)
  #(next_model, quick_action_scroll.ensure_visible(selected_index))
}

fn action_at(
  actions: List(top_bar.Action(Msg)),
  index: Int,
) -> option.Option(top_bar.Action(Msg)) {
  case actions, index {
    [first, ..], 0 -> option.Some(first)
    [_, ..rest], _ if index > 0 -> action_at(rest, index - 1)
    _, _ -> option.None
  }
}

fn cap_section_actions(
  section: top_bar.Section(Msg),
  max_actions: Int,
) -> top_bar.Section(Msg) {
  case section {
    top_bar.Section(title:, actions:) ->
      top_bar.Section(title:, actions: list.take(actions, max_actions))
  }
}

fn sort_section_actions(
  section: top_bar.Section(Msg),
  query: String,
) -> top_bar.Section(Msg) {
  case section {
    top_bar.Section(title:, actions:) ->
      top_bar.Section(
        title:,
        actions: list.sort(actions, by: compare_actions(query)),
      )
  }
}

fn compare_actions(
  query: String,
) -> fn(top_bar.Action(Msg), top_bar.Action(Msg)) -> order.Order {
  fn(left: top_bar.Action(Msg), right: top_bar.Action(Msg)) {
    let left_score = action_score(left, query)
    let right_score = action_score(right, query)

    let tie_break = case left, right {
      top_bar.Action(label: left_label, ..),
        top_bar.Action(label: right_label, ..)
      -> string.compare(left_label, right_label)
    }

    order.break_tie(in: int.compare(right_score, left_score), with: tie_break)
  }
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
