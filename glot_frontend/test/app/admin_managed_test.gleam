import gleam/option
import gleam/string
import gleam/time/timestamp
import gleeunit
import glot_core/admin/rate_limit_config_dto
import glot_core/auth/session_dto
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/route
import glot_frontend/admin/command
import glot_frontend/admin/effect/config
import glot_frontend/admin/effect/users
import glot_frontend/admin/router
import glot_frontend/api/response
import glot_frontend/app/admin_managed
import lustre/element
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn authenticated_spa_navigation_loads_and_accepts_the_initial_response_test() {
  let #(initial, _) =
    admin_managed.init(
      route.Admin(route.AdminHome),
      timestamp.from_unix_seconds(1),
      True,
      pages(),
    )
  let #(authenticated, _) =
    admin_managed.update(
      initial,
      admin_managed.SessionLoaded(
        response.Success(option.Some(admin_session())),
      ),
      pages(),
    )
  let #(loading, navigation_command) =
    admin_managed.update(
      authenticated,
      admin_managed.UserNavigatedTo(route.Admin(route.AdminRateLimits)),
      pages(),
    )
  let assert admin_managed.Batch([
    admin_managed.RunAdmin(command.Batch([
      command.None,
      command.Config(config.GetRateLimits(complete)),
    ])),
    admin_managed.TrackPageview(route.Admin(route.AdminRateLimits)),
  ]) = navigation_command

  let #(failed, _) =
    admin_managed.update(
      loading,
      admin_managed.AdminPagesMsg(
        complete(
          response.ApiFailure(response.Error(
            code: "fixture",
            message: "Navigation request completed.",
            request_id: uuid.v7(),
          )),
        ),
      ),
      pages(),
    )
  let rendered =
    router.view(failed.page_model, failed.runtime.now)
    |> element.to_document_string
  assert string.contains(rendered, "Navigation request completed.")
}

pub fn response_from_page_left_during_navigation_is_ignored_test() {
  let #(initial, _) =
    admin_managed.init(
      route.Admin(route.AdminHome),
      timestamp.from_unix_seconds(1),
      True,
      pages(),
    )
  let #(authenticated, _) =
    admin_managed.update(
      initial,
      admin_managed.SessionLoaded(
        response.Success(option.Some(admin_session())),
      ),
      pages(),
    )
  let #(rate_limits, rate_command) =
    admin_managed.update(
      authenticated,
      admin_managed.UserNavigatedTo(route.Admin(route.AdminRateLimits)),
      pages(),
    )
  let assert admin_managed.Batch([
    admin_managed.RunAdmin(command.Batch([
      command.None,
      command.Config(config.GetRateLimits(rate_loaded)),
    ])),
    admin_managed.TrackPageview(_),
  ]) = rate_command

  let #(users_page, users_command) =
    admin_managed.update(
      rate_limits,
      admin_managed.UserNavigatedTo(route.Admin(route.AdminUsers)),
      pages(),
    )
  let assert admin_managed.Batch([
    admin_managed.RunAdmin(command.Batch([
      command.None,
      command.Users(users.GetUsers(_, _)),
    ])),
    admin_managed.TrackPageview(_),
  ]) = users_command

  let stale =
    rate_loaded(
      response.Success(rate_limit_config_dto.RateLimitPoliciesResponse([])),
    )
  let #(unchanged, next_command) =
    admin_managed.update(
      users_page,
      admin_managed.AdminPagesMsg(stale),
      pages(),
    )
  assert unchanged == users_page
  assert next_command == admin_managed.RunAdmin(command.None)
}

pub fn leaving_the_admin_app_requests_a_document_navigation_test() {
  let #(model, _) =
    admin_managed.init(
      route.Admin(route.AdminHome),
      timestamp.from_unix_seconds(1),
      True,
      pages(),
    )
  let #(unchanged, command) =
    admin_managed.update(
      model,
      admin_managed.UserNavigatedTo(route.Public(route.Home)),
      pages(),
    )
  assert unchanged == model
  assert command == admin_managed.LoadRoute(route.Public(route.Home))
}

pub fn lifecycle_uses_the_injected_page_contract_test() {
  let fixture_pages =
    admin_managed.Pages(
      empty: fn() { "empty" },
      init: fn(admin_route, is_admin) {
        let page = case admin_route, is_admin {
          route.AdminRateLimits, True -> "rate-limits:admin"
          _, True -> "other:admin"
          _, False -> "unauthorized"
        }
        #(page, "initial-request")
      },
      session_loaded: fn(page) { #(page <> ":session", "session-request") },
      update: fn(_page, message) { #(message, "update-request") },
      none: "none",
    )
  let #(model, initial_command) =
    admin_managed.init(
      route.Admin(route.AdminRateLimits),
      timestamp.from_unix_seconds(1),
      True,
      fixture_pages,
    )
  let assert admin_managed.Batch([
    admin_managed.RunAdmin("initial-request"),
    admin_managed.TrackPageview(route.Admin(route.AdminRateLimits)),
    admin_managed.GetSession,
    admin_managed.ScheduleTick,
  ]) = initial_command
  assert model.page_model == "unauthorized"

  let #(authenticated, command) =
    admin_managed.update(
      model,
      admin_managed.SessionLoaded(
        response.Success(option.Some(admin_session())),
      ),
      fixture_pages,
    )
  assert authenticated.page_model == "unauthorized:session"
  assert command == admin_managed.RunAdmin("session-request")

  let #(updated, command) =
    admin_managed.update(
      authenticated,
      admin_managed.AdminPagesMsg("updated-page"),
      fixture_pages,
    )
  assert updated.page_model == "updated-page"
  assert command == admin_managed.RunAdmin("update-request")
}

fn pages() -> admin_managed.Pages(
  router.Model,
  router.Msg,
  command.Command(router.Msg),
) {
  admin_managed.Pages(
    empty: router.empty,
    init: router.init,
    session_loaded: router.session_loaded,
    update: router.update,
    none: command.none(),
  )
}

fn admin_session() -> session_dto.SessionResponse {
  session_dto.SessionResponse(
    id: uuid.v7(),
    user: session_dto.SessionUserResponse(
      id: uuid.v7(),
      email: email_address_model.EmailAddress("admin@example.com"),
      username: "admin",
      role: user_model.AdminUser,
    ),
    created_at: timestamp.from_unix_seconds(1),
  )
}
