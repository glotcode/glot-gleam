import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/route
import glot_frontend/account/message as account_message
import glot_frontend/account/model as account_model
import glot_frontend/account/page as account_page
import glot_frontend/account/snippets/page as manage_snippets_page
import glot_frontend/app/runtime
import glot_frontend/public/contact/page as contact_page
import glot_frontend/public/editor/message as editor_message
import glot_frontend/public/editor/model as editor_model
import glot_frontend/public/editor/page as editor_page
import glot_frontend/public/home/page as home_page
import glot_frontend/public/login/page as login_page
import glot_frontend/public/snippets/message as snippets_message
import glot_frontend/public/snippets/model as snippets_model
import glot_frontend/public/snippets/page as snippets_page
import glot_frontend/ui/not_found
import glot_web/page/privacy
import glot_web/page/seo
import glot_web/page/top_bar
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import youid/uuid.{type Uuid}

pub type Model {
  Home(home_page.Model)
  Contact(contact_page.Model)
  Privacy
  Login(login_page.Model)
  Account(account_model.Model)
  ManageSnippets(manage_snippets_page.Model)
  Snippets(snippets_model.Model)
  Editor(editor_model.Model)
  Empty
}

pub type Messages(msg) {
  Messages(
    home: fn(home_page.Msg) -> msg,
    contact: fn(contact_page.Msg) -> msg,
    login: fn(login_page.Msg) -> msg,
    account: fn(account_message.Msg) -> msg,
    manage_snippets: fn(manage_snippets_page.Msg) -> msg,
    snippets: fn(snippets_message.Msg) -> msg,
    editor: fn(editor_message.Msg) -> msg,
  )
}

pub fn init(
  target: route.Route,
  session: runtime.SessionState,
  messages: Messages(msg),
) -> #(Model, Effect(msg)) {
  case target {
    route.Public(public_route) -> init_public(public_route, session, messages)
    route.Account(account_route) -> init_account(account_route, messages)
    route.Admin(_) | route.NotFound(_) -> #(Empty, effect.none())
  }
}

fn init_public(
  target: route.PublicRoute,
  session: runtime.SessionState,
  messages: Messages(msg),
) -> #(Model, Effect(msg)) {
  case target {
    route.Home -> map_init(home_page.init(), Home, messages.home)
    route.Contact ->
      map_init(
        contact_page.init(runtime.current_user_email(session)),
        Contact,
        messages.contact,
      )
    route.Privacy -> #(Privacy, effect.none())
    route.Login -> map_init(login_page.init(), Login, messages.login)
    route.Snippets(after:, before:, username:) ->
      map_init(
        snippets_page.init(after:, before:, username:),
        Snippets,
        messages.snippets,
      )
    route.NewSnippet(language) ->
      map_init(editor_page.init_new(language), Editor, messages.editor)
    route.Snippet(slug) ->
      map_init(editor_page.init_existing(slug), Editor, messages.editor)
  }
}

fn init_account(
  target: route.AccountRoute,
  messages: Messages(msg),
) -> #(Model, Effect(msg)) {
  case target {
    route.AccountHome ->
      map_init(account_page.init(), Account, messages.account)
    route.AccountSnippets(after:, before:) ->
      map_init(
        manage_snippets_page.init(after:, before:),
        ManageSnippets,
        messages.manage_snippets,
      )
  }
}

fn map_init(
  initialized: #(child_model, Effect(child_msg)),
  wrap_model: fn(child_model) -> Model,
  wrap_msg: fn(child_msg) -> msg,
) -> #(Model, Effect(msg)) {
  #(wrap_model(initialized.0), effect.map(initialized.1, wrap_msg))
}

pub fn session_loaded(model: Model, session: runtime.SessionState) -> Model {
  case model {
    Contact(contact_model) ->
      Contact(contact_page.session_loaded(
        contact_model,
        runtime.current_user_email(session),
      ))
    _ -> model
  }
}

pub fn metadata(model: Model, current_route: route.Route) -> seo.Metadata {
  case model {
    Home(_) -> seo.home()
    Contact(_) -> seo.contact()
    Privacy -> seo.privacy()
    Login(_) -> seo.login()
    Snippets(page_model) ->
      snippets_page.metadata(page_model, route.to_string(current_route))
    Editor(page_model) -> editor_page.metadata(page_model)
    Account(_) ->
      private_metadata(
        "Account | glot.io",
        "Secure glot.io account page.",
        "/account",
      )
    ManageSnippets(_) ->
      private_metadata(
        "Your snippets | glot.io",
        "Manage your glot.io code snippets.",
        "/account/snippets",
      )
    Empty ->
      private_metadata(
        "Page not found | glot.io",
        "The requested glot.io page could not be found.",
        "/",
      )
  }
}

fn private_metadata(
  title: String,
  description: String,
  path: String,
) -> seo.Metadata {
  seo.metadata(
    title:,
    description:,
    canonical_path: path,
    index: False,
    open_graph_type: "website",
  )
}

pub fn view(
  model: Model,
  session: runtime.SessionState,
  now: Timestamp,
  messages: Messages(msg),
) -> Element(msg) {
  case model {
    Home(page) -> home_page.view(page) |> element.map(messages.home)
    Contact(page) -> contact_page.view(page) |> element.map(messages.contact)
    Privacy -> privacy.view()
    Login(page) -> login_page.view(page) |> element.map(messages.login)
    Account(page) ->
      account_page.view(page, now) |> element.map(messages.account)
    ManageSnippets(page) ->
      manage_snippets_page.view(page, now)
      |> element.map(messages.manage_snippets)
    Snippets(page) ->
      snippets_page.view(page, now) |> element.map(messages.snippets)
    Editor(page) ->
      editor_page.view(page, runtime.current_user_id(session), now)
      |> element.map(messages.editor)
    Empty -> not_found.view()
  }
}

pub fn quick_actions(
  model: Model,
  current_user_id: option.Option(Uuid),
  on_editor_action: fn(editor_message.Msg) -> msg,
) -> List(top_bar.Action(msg)) {
  case model {
    Editor(editor) ->
      list.map(editor_page.quick_actions(editor, current_user_id), fn(action) {
        top_bar.map_action(action, on_editor_action)
      })
    _ -> []
  }
}
