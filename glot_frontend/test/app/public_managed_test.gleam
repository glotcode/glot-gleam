import gleam/time/timestamp
import gleeunit
import glot_core/route
import glot_frontend/app/public_managed
import glot_frontend/app/runtime

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn public_navigation_reinitializes_the_page_and_lifecycle_commands_test() {
  let #(model, _) =
    public_managed.init(
      route.Public(route.Home),
      timestamp.from_unix_seconds(1),
      True,
      init_page,
    )
  let destination = route.Public(route.Contact)
  let #(navigated, command) =
    public_managed.update(
      model,
      public_managed.UserNavigatedTo(destination),
      init_page,
      session_loaded,
    )

  assert navigated.route == destination
  assert navigated.page_model == "/contact"
  assert command
    == public_managed.Batch([
      public_managed.RunPage("load:/contact"),
      public_managed.TrackPageview(destination),
      public_managed.ApplyMetadata,
    ])
}

pub fn admin_navigation_leaves_public_state_untouched_test() {
  let #(model, _) =
    public_managed.init(
      route.Public(route.Home),
      timestamp.from_unix_seconds(1),
      True,
      init_page,
    )
  let destination = route.Admin(route.AdminHome)
  let #(unchanged, command) =
    public_managed.update(
      model,
      public_managed.UserNavigatedTo(destination),
      init_page,
      session_loaded,
    )

  assert unchanged == model
  assert command == public_managed.LoadRoute(destination)
}

fn init_page(
  target: route.Route,
  _session: runtime.SessionState,
) -> #(String, String) {
  let path = route.to_string(target)
  #(path, "load:" <> path)
}

fn session_loaded(page: String, _session: runtime.SessionState) -> String {
  page
}
