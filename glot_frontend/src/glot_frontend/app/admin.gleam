import gleam/option
import glot_core/route
import glot_frontend/admin/command as admin_command
import glot_frontend/admin/router as admin_pages
import glot_frontend/admin/ui/breadcrumbs as admin_breadcrumbs
import glot_frontend/app/admin_managed
import glot_frontend/app/admin_production
import glot_frontend/app/public_quick_actions
import glot_frontend/app/quick_actions
import glot_frontend/app/quick_actions_managed
import glot_frontend/app/runtime as app_shell
import glot_frontend/platform/app_dialog
import glot_frontend/platform/browser_navigation
import glot_frontend/platform/clock
import glot_frontend/platform/keyboard_shortcuts
import glot_frontend/platform/page_visibility
import glot_frontend/platform/quick_action_scroll
import glot_web/page/site_chrome
import glot_web/page/top_bar
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
    lifecycle: admin_managed.Model(admin_pages.Model),
    quick_actions: quick_actions.Model,
  )
}

type QuickActionTarget {
  NavigateTo(route.Route)
}

type Flags {
  Flags
}

fn init(_flags: Flags) -> #(Model, Effect(Msg)) {
  let initial_route = case modem.initial_uri() {
    Ok(uri) -> route.from_uri(uri)
    Error(_) -> route.Public(route.Home)
  }
  let #(lifecycle, lifecycle_command) =
    admin_managed.init(
      initial_route,
      clock.now(),
      page_visibility.document_is_visible(),
      pages(),
    )
  let navigation_effect =
    modem.init(fn(uri) {
      uri
      |> route.from_uri
      |> admin_managed.UserNavigatedTo
      |> AdminManagedMsg
    })
  let shortcut_effect =
    keyboard_shortcuts.bind(
      QuickActionsMsg(quick_actions_managed.Opened),
      IgnoredEditorRunShortcut,
    )
  #(
    Model(lifecycle:, quick_actions: quick_actions.init()),
    effect.batch([
      navigation_effect,
      admin_production.run(lifecycle_command) |> effect.map(AdminManagedMsg),
      shortcut_effect,
    ]),
  )
}

type Msg {
  AdminManagedMsg(admin_managed.Msg(admin_pages.Msg))
  QuickActionsMsg(quick_actions_managed.Msg)
  QuickActionSelected(QuickActionTarget)
  IgnoredEditorRunShortcut
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    AdminManagedMsg(lifecycle_msg) -> {
      let #(lifecycle, command) =
        admin_managed.update(model.lifecycle, lifecycle_msg, pages())
      let next_model = Model(..model, lifecycle:)
      let #(next_model, quick_action_effect) = case lifecycle_msg {
        admin_managed.UserNavigatedTo(_) ->
          update_quick_actions(next_model, quick_actions_managed.Reset)
        _ -> #(next_model, effect.none())
      }
      #(
        next_model,
        effect.batch([
          quick_action_effect,
          admin_production.run(command) |> effect.map(AdminManagedMsg),
        ]),
      )
    }

    QuickActionsMsg(quick_action_msg) ->
      update_quick_actions(model, quick_action_msg)

    QuickActionSelected(target) ->
      handle_quick_action(
        Model(
          ..model,
          quick_actions: quick_actions.clear_query(model.quick_actions),
        ),
        target,
      )

    IgnoredEditorRunShortcut -> #(model, effect.none())
  }
}

fn pages() -> admin_managed.Pages(
  admin_pages.Model,
  admin_pages.Msg,
  admin_command.Command(admin_pages.Msg),
) {
  admin_managed.Pages(
    empty: admin_pages.empty,
    init: admin_pages.init,
    session_loaded: admin_pages.session_loaded,
    update: admin_pages.update,
    none: admin_command.none(),
  )
}

fn view(model: Model) -> Element(Msg) {
  case app_shell.is_admin(model.lifecycle.runtime.session) {
    True -> admin_view(model)
    False -> element.none()
  }
}

fn admin_view(model: Model) -> Element(Msg) {
  let page_content =
    admin_pages.view(model.lifecycle.page_model, model.lifecycle.runtime.now)
    |> element.map(fn(msg) { AdminManagedMsg(admin_managed.AdminPagesMsg(msg)) })

  let content = case admin_breadcrumbs.is_admin_route(model.lifecycle.route) {
    True -> admin_breadcrumbs.wrap(model.lifecycle.route, page_content)
    False -> page_content
  }

  site_chrome.view(
    top_bar_model: top_bar_model(model),
    footer_account_route: app_shell.current_user_route(
      model.lifecycle.runtime.session,
    ),
    content: content,
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

fn quick_action_sections(
  model: Model,
) -> List(top_bar.Section(QuickActionTarget)) {
  public_quick_actions.sections(
    model.lifecycle.runtime.session,
    model.lifecycle.route,
    model.quick_actions.query,
    [],
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
