import gleam/option
import gleam/string
import glot_core/auth/session_dto
import glot_frontend/account_page
import glot_frontend/api
import glot_frontend/app_event
import glot_frontend/editor_page
import glot_frontend/home_page
import glot_frontend/login_page
import glot_frontend/route
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
  Model(route: route.Route, page_model: PageModel, session: SessionState)
}

type PageModel {
  HomePageModel(home_page.Model)
  LoginPage(login_page.Model)
  AccountPage(account_page.Model)
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

    route.Snippets(after:, before:) -> {
      let #(m, eff) = snippets_page.init(after:, before:)
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

  let effects = effect.batch([eff, page_effect, session_effect])

  #(Model(route: r, page_model: page_model, session: LoadingSession), effects)
}

type Msg {
  UserNavigatedTo(route: route.Route)
  SessionLoaded(api.ApiResponse(option.Option(session_dto.SessionResponse)))
  HomePageMsg(home_page.Msg)
  LoginPageMsg(login_page.Msg)
  AccountPageMsg(account_page.Msg)
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

    HomePageMsg(page_msg), HomePageModel(page_model) -> {
      let #(new_page_model, page_effect) =
        home_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: HomePageModel(new_page_model))
      #(new_model, effect.map(page_effect, HomePageMsg))
    }

    LoginPageMsg(page_msg), LoginPage(page_model) -> {
      let #(new_page_model, page_effect, app_event) =
        login_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: LoginPage(new_page_model))
      let mapped_effect = effect.map(page_effect, LoginPageMsg)
      let effects = apply_app_event(mapped_effect, app_event)
      #(new_model, effects)
    }

    AccountPageMsg(page_msg), AccountPage(page_model) -> {
      let #(new_page_model, page_effect, app_event) =
        account_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: AccountPage(new_page_model))
      let mapped_effect = effect.map(page_effect, AccountPageMsg)
      let effects = apply_app_event(mapped_effect, app_event)
      #(new_model, effects)
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
      #(Model(..model, route:, page_model:), page_effect)
    }

    _, _ -> {
      #(model, effect.none())
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  case model.page_model {
    EmptyPageModel -> {
      not_found_view()
    }

    HomePageModel(page_model) -> {
      let elem =
        home_page.view(
          page_model,
          current_user_label(model.session),
          current_user_route(model.session),
        )
      element.map(elem, HomePageMsg)
    }

    LoginPage(page_model) -> {
      let elem =
        login_page.view(
          page_model,
          current_user_label(model.session),
          current_user_route(model.session),
        )
      element.map(elem, LoginPageMsg)
    }

    AccountPage(page_model) -> {
      let elem =
        account_page.view(
          page_model,
          current_user_label(model.session),
          current_user_route(model.session),
        )
      element.map(elem, AccountPageMsg)
    }

    SnippetsPage(page_model) -> {
      let elem =
        snippets_page.view(
          page_model,
          current_user_label(model.session),
          current_user_route(model.session),
        )
      element.map(elem, SnippetsPageMsg)
    }

    EditorPage(page_model) -> {
      let elem =
        editor_page.view(
          page_model,
          current_user_id(model.session),
          current_user_label(model.session),
          current_user_route(model.session),
        )
      element.map(elem, EditorPageMsg)
    }
  }
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
