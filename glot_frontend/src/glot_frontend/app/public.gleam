import gleam/list
import gleam/option
import glot_core/route
import glot_frontend/account/message as account_message
import glot_frontend/account/page as account_page
import glot_frontend/account/snippets/page as manage_snippets_page
import glot_frontend/api/account as account_api
import glot_frontend/app/public_managed
import glot_frontend/app/public_page
import glot_frontend/app/public_quick_actions
import glot_frontend/app/quick_actions
import glot_frontend/app/quick_actions_managed
import glot_frontend/app/runtime as app_shell
import glot_frontend/app/runtime_production
import glot_frontend/platform/app_dialog
import glot_frontend/platform/browser_navigation
import glot_frontend/platform/clock
import glot_frontend/platform/keyboard_shortcuts
import glot_frontend/platform/page_metadata
import glot_frontend/platform/page_visibility
import glot_frontend/platform/quick_action_scroll
import glot_frontend/public/contact/page as contact_page
import glot_frontend/public/editor/message as editor_message
import glot_frontend/public/editor/page as editor_page
import glot_frontend/public/home/page as home_page
import glot_frontend/public/login/page as login_page
import glot_frontend/public/snippets/message as snippets_message
import glot_frontend/public/snippets/page as snippets_page
import glot_web/page/seo
import glot_web/page/site_chrome
import glot_web/page/top_bar
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
    lifecycle: public_managed.Model(public_page.Model),
    quick_actions: quick_actions.Model,
  )
}

type QuickActionTarget {
  NavigateTo(route.Route)
  TriggerEditorAction(editor_message.Msg)
}

fn init_page(
  target: route.Route,
  session: app_shell.SessionState,
) -> #(public_page.Model, Effect(Msg)) {
  public_page.init(target, session, page_messages())
}

fn page_messages() -> public_page.Messages(Msg) {
  public_page.Messages(
    home: HomePageMsg,
    contact: ContactPageMsg,
    login: LoginPageMsg,
    account: AccountPageMsg,
    manage_snippets: ManageSnippetsPageMsg,
    snippets: SnippetsPageMsg,
    editor: EditorPageMsg,
  )
}

type Flags {
  Flags
}

fn init(_flags: Flags) -> #(Model, Effect(Msg)) {
  let current_route = case modem.initial_uri() {
    Ok(uri) -> route.from_uri(uri)
    Error(_) -> route.Public(route.Home)
  }
  let #(lifecycle, lifecycle_command) =
    public_managed.init(
      current_route,
      clock.now(),
      page_visibility.document_is_visible(),
      init_page,
    )
  let navigation_effect =
    modem.init(fn(uri) {
      uri
      |> route.from_uri
      |> public_managed.UserNavigatedTo
      |> PublicManagedMsg
    })
  let model = Model(lifecycle:, quick_actions: quick_actions.init())

  #(
    model,
    effect.batch([
      navigation_effect,
      run_lifecycle_command(lifecycle_command, model),
      keyboard_shortcuts.bind(
        QuickActionsMsg(quick_actions_managed.Opened),
        EditorRunShortcutPressed,
      ),
    ]),
  )
}

type Msg {
  PublicManagedMsg(public_managed.Msg)
  QuickActionsMsg(quick_actions_managed.Msg)
  QuickActionSelected(QuickActionTarget)
  EditorRunShortcutPressed
  HomePageMsg(home_page.Msg)
  ContactPageMsg(contact_page.Msg)
  LoginPageMsg(login_page.Msg)
  AccountPageMsg(account_message.Msg)
  ManageSnippetsPageMsg(manage_snippets_page.Msg)
  SnippetsPageMsg(snippets_message.Msg)
  EditorPageMsg(editor_message.Msg)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.lifecycle.page_model {
    PublicManagedMsg(lifecycle_msg), _ -> {
      let #(lifecycle, command) =
        public_managed.update(
          model.lifecycle,
          lifecycle_msg,
          init_page,
          page_session_loaded,
        )
      let next_model = Model(..model, lifecycle:)
      let #(next_model, quick_action_effect) = case lifecycle_msg {
        public_managed.UserNavigatedTo(_) ->
          update_quick_actions(next_model, quick_actions_managed.Reset)
        _ -> #(next_model, effect.none())
      }
      #(
        next_model,
        effect.batch([
          quick_action_effect,
          run_lifecycle_command(command, next_model),
        ]),
      )
    }

    QuickActionsMsg(quick_action_msg), _ ->
      update_quick_actions(model, quick_action_msg)
    QuickActionSelected(target), _ ->
      handle_quick_action(
        Model(
          ..model,
          quick_actions: quick_actions.clear_query(model.quick_actions),
        ),
        target,
      )

    EditorRunShortcutPressed, public_page.Editor(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(
          page_model,
          editor_message.RunSubmitted,
          app_shell.current_user_id(model.lifecycle.runtime.session),
        )
      #(
        with_page_model(model, public_page.Editor(new_page_model)),
        effect.map(page_effect, EditorPageMsg),
      )
    }
    HomePageMsg(page_msg), public_page.Home(page_model) -> {
      let #(new_page_model, page_effect) =
        home_page.update(page_model, page_msg)
      #(
        with_page_model(model, public_page.Home(new_page_model)),
        effect.map(page_effect, HomePageMsg),
      )
    }
    ContactPageMsg(page_msg), public_page.Contact(page_model) -> {
      let #(new_page_model, page_effect) =
        contact_page.update(page_model, page_msg)
      #(
        with_page_model(model, public_page.Contact(new_page_model)),
        effect.map(page_effect, ContactPageMsg),
      )
    }
    LoginPageMsg(page_msg), public_page.Login(page_model) -> {
      let #(new_page_model, page_effect, event) =
        login_page.update(page_model, page_msg)
      #(
        with_page_model(model, public_page.Login(new_page_model)),
        runtime_production.apply_app_event(
          effect.map(page_effect, LoginPageMsg),
          event,
          fn(result) { PublicManagedMsg(public_managed.SessionLoaded(result)) },
        ),
      )
    }
    AccountPageMsg(page_msg), public_page.Account(page_model) -> {
      let #(new_page_model, page_effect, event) =
        account_page.update(page_model, page_msg)
      #(
        with_page_model(model, public_page.Account(new_page_model)),
        runtime_production.apply_app_event(
          effect.map(page_effect, AccountPageMsg),
          event,
          fn(result) { PublicManagedMsg(public_managed.SessionLoaded(result)) },
        ),
      )
    }
    ManageSnippetsPageMsg(page_msg), public_page.ManageSnippets(page_model) -> {
      let #(new_page_model, page_effect) =
        manage_snippets_page.update(page_model, page_msg)
      #(
        with_page_model(model, public_page.ManageSnippets(new_page_model)),
        effect.map(page_effect, ManageSnippetsPageMsg),
      )
    }
    SnippetsPageMsg(page_msg), public_page.Snippets(page_model) -> {
      let #(new_page_model, page_effect) =
        snippets_page.update(page_model, page_msg)
      let next_model =
        with_page_model(model, public_page.Snippets(new_page_model))
      #(next_model, effect.map(page_effect, SnippetsPageMsg))
    }
    EditorPageMsg(page_msg), public_page.Editor(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(
          page_model,
          page_msg,
          app_shell.current_user_id(model.lifecycle.runtime.session),
        )
      let next_model =
        with_page_model(model, public_page.Editor(new_page_model))
      let metadata_effect = case editor_page.affects_metadata(page_msg) {
        True -> metadata_effect(next_model)
        False -> effect.none()
      }
      #(
        next_model,
        effect.batch([
          effect.map(page_effect, EditorPageMsg),
          metadata_effect,
        ]),
      )
    }

    _, _ -> #(model, effect.none())
  }
}

fn page_session_loaded(
  page_model: public_page.Model,
  session: app_shell.SessionState,
) -> public_page.Model {
  public_page.session_loaded(page_model, session)
}

fn with_page_model(model: Model, page_model: public_page.Model) -> Model {
  Model(
    ..model,
    lifecycle: public_managed.Model(..model.lifecycle, page_model:),
  )
}

fn run_lifecycle_command(
  command: public_managed.Command(Effect(Msg)),
  model: Model,
) -> Effect(Msg) {
  case command {
    public_managed.None -> effect.none()
    public_managed.Batch(commands) ->
      effect.batch(
        list.map(commands, fn(command) { run_lifecycle_command(command, model) }),
      )
    public_managed.RunPage(page_effect) -> page_effect
    public_managed.GetSession ->
      account_api.get_session(fn(result) {
        PublicManagedMsg(public_managed.SessionLoaded(result))
      })
    public_managed.RefreshSession ->
      account_api.refresh_session(fn(result) {
        PublicManagedMsg(public_managed.SessionRefreshed(result))
      })
    public_managed.TrackPageview(target) ->
      runtime_production.track_pageview(target, fn(result) {
        PublicManagedMsg(public_managed.PageviewTracked(result))
      })
    public_managed.ApplyMetadata -> metadata_effect(model)
    public_managed.ScheduleTick ->
      clock.schedule_next_tick(fn(now) {
        PublicManagedMsg(public_managed.ClockTicked(
          now,
          page_visibility.document_is_visible(),
        ))
      })
    public_managed.LoadRoute(target) ->
      browser_navigation.load(route.to_string(target))
  }
}

fn metadata_effect(model: Model) -> Effect(Msg) {
  page_metadata.apply(metadata(model))
}

fn metadata(model: Model) -> seo.Metadata {
  public_page.metadata(model.lifecycle.page_model, model.lifecycle.route)
}

fn view(model: Model) -> Element(Msg) {
  let content =
    public_page.view(
      model.lifecycle.page_model,
      model.lifecycle.runtime.session,
      model.lifecycle.runtime.now,
      page_messages(),
    )

  site_chrome.view(
    top_bar_model: top_bar_model(model),
    footer_account_route: app_shell.current_user_route(
      model.lifecycle.runtime.session,
    ),
    content:,
  )
}

fn top_bar_model(model: Model) -> top_bar.ViewModel(Msg) {
  public_quick_actions.view_model(
    model.lifecycle.runtime.session,
    model.quick_actions,
    quick_action_sections(model),
    quick_action_messages(),
    QuickActionSelected,
  )
}

fn quick_action_messages() -> public_quick_actions.Messages(Msg) {
  public_quick_actions.Messages(
    open: QuickActionsMsg(quick_actions_managed.Opened),
    close: QuickActionsMsg(quick_actions_managed.Dismissed),
    query_changed: fn(query) {
      QuickActionsMsg(quick_actions_managed.QueryChanged(query))
    },
    key_pressed: fn(key) {
      QuickActionsMsg(quick_actions_managed.KeyPressed(key))
    },
    submitted: QuickActionsMsg(quick_actions_managed.Submitted),
  )
}

fn page_actions(
  page_model: public_page.Model,
  current_user_id: option.Option(uuid.Uuid),
) -> List(top_bar.Action(QuickActionTarget)) {
  public_page.quick_actions(page_model, current_user_id, fn(msg) {
    TriggerEditorAction(msg)
  })
}

fn handle_quick_action(
  model: Model,
  target: QuickActionTarget,
) -> #(Model, Effect(Msg)) {
  let close_effect = app_dialog.close(top_bar.quick_actions_dialog_id)
  case target, model.lifecycle.page_model {
    NavigateTo(destination), _ -> #(
      model,
      effect.batch([close_effect, navigate_to(destination)]),
    )
    TriggerEditorAction(page_msg), public_page.Editor(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(
          page_model,
          page_msg,
          app_shell.current_user_id(model.lifecycle.runtime.session),
        )
      #(
        with_page_model(model, public_page.Editor(new_page_model)),
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

fn quick_action_sections(
  model: Model,
) -> List(top_bar.Section(QuickActionTarget)) {
  public_quick_actions.sections(
    model.lifecycle.runtime.session,
    model.lifecycle.route,
    model.quick_actions.query,
    page_actions(
      model.lifecycle.page_model,
      app_shell.current_user_id(model.lifecycle.runtime.session),
    ),
    NavigateTo,
  )
}

fn update_quick_actions(
  model: Model,
  msg: quick_actions_managed.Msg,
) -> #(Model, Effect(Msg)) {
  let #(quick_actions, command) =
    quick_actions_managed.update(
      model.quick_actions,
      msg,
      quick_action_sections(model),
    )
  let next_model = Model(..model, quick_actions:)
  case command {
    quick_actions_managed.None -> #(next_model, effect.none())
    quick_actions_managed.OpenDialog -> #(
      next_model,
      app_dialog.open(top_bar.quick_actions_dialog_id),
    )
    quick_actions_managed.CloseDialog -> #(
      next_model,
      app_dialog.close(top_bar.quick_actions_dialog_id),
    )
    quick_actions_managed.ScrollTo(index) -> #(
      next_model,
      quick_action_scroll.ensure_visible(index),
    )
    quick_actions_managed.Run(target) -> handle_quick_action(next_model, target)
  }
}
