import gleam/list
import gleam/option
import gleeunit
import glot_core/route
import glot_frontend/app/public_page
import glot_frontend/app/public_quick_actions
import glot_frontend/app/quick_actions
import glot_frontend/app/runtime
import glot_web/page/top_bar

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn privacy_route_initializes_the_privacy_page_test() {
  let #(model, _) =
    public_page.init(
      route.Public(route.Privacy),
      runtime.LoadingSession,
      messages(),
    )

  assert model == public_page.Privacy
}

pub fn routes_owned_by_the_other_application_initialize_empty_test() {
  let #(model, _) =
    public_page.init(
      route.Admin(route.AdminHome),
      runtime.LoadingSession,
      messages(),
    )

  assert model == public_page.Empty
}

pub fn initial_home_quick_actions_keep_the_default_navigation_test() {
  let sections =
    public_quick_actions.sections(
      runtime.LoadingSession,
      route.Public(route.Home),
      "",
      [],
      route.to_string,
    )

  assert list.length(sections) == 2
  let assert [top_bar.Section(title: "Navigation", ..), ..] = sections
}

pub fn page_actions_participate_in_filtering_and_selection_test() {
  let page_action =
    top_bar.Action(
      label: "Fixture action",
      description: "Test action",
      shortcut: [],
      target_route: option.None,
      msg: "fixture",
    )
  let sections =
    public_quick_actions.sections(
      runtime.LoadingSession,
      route.Public(route.Contact),
      "fixture",
      [page_action],
      route.to_string,
    )
  let assert option.Some(top_bar.Action(msg: selected, ..)) =
    public_quick_actions.selected(quick_actions.init(), sections)

  assert selected == "fixture"
}

fn messages() -> public_page.Messages(Nil) {
  public_page.Messages(
    home: fn(_) { Nil },
    contact: fn(_) { Nil },
    login: fn(_) { Nil },
    account: fn(_) { Nil },
    manage_snippets: fn(_) { Nil },
    snippets: fn(_) { Nil },
    editor: fn(_) { Nil },
  )
}
