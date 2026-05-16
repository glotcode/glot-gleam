import gleam/dict
import gleam/option
import gleam/uri
import gleeunit
import glot_backend/domain/shared/availability_policy_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_algebra
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_core/admin_action
import glot_core/api_action
import glot_core/availability_mode
import glot_core/public_action
import glot_core/route

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn normal_mode_allows_public_write_api_test() {
  let config = availability_config(availability_mode.NormalMode)

  assert run_policy_program(
      availability_policy_domain.enforce_api_action(api_action.public(
        public_action.CreateSnippetAction,
      )),
      config,
    )
    == Ok(Nil)
}

pub fn read_only_mode_blocks_public_write_api_test() {
  let config = availability_config(availability_mode.ReadOnlyMode)

  assert run_policy_program(
      availability_policy_domain.enforce_api_action(api_action.public(
        public_action.CreateSnippetAction,
      )),
      config,
    )
    == Error(
      error.AvailabilityError(error.AvailabilityBlockedError(
        code: "read_only_mode_enabled",
        message: config.message,
        retry_after_seconds: config.retry_after_seconds,
      )),
    )
}

pub fn read_only_mode_allows_public_read_api_test() {
  let config = availability_config(availability_mode.ReadOnlyMode)

  assert run_policy_program(
      availability_policy_domain.enforce_api_action(api_action.public(
        public_action.ListPublicSnippetsAction,
      )),
      config,
    )
    == Ok(Nil)
}

pub fn maintenance_mode_blocks_public_read_api_test() {
  let config = availability_config(availability_mode.MaintenanceMode)

  assert run_policy_program(
      availability_policy_domain.enforce_api_action(api_action.public(
        public_action.ListPublicSnippetsAction,
      )),
      config,
    )
    == Error(
      error.AvailabilityError(error.AvailabilityBlockedError(
        code: "maintenance_mode_enabled",
        message: config.message,
        retry_after_seconds: config.retry_after_seconds,
      )),
    )
}

pub fn maintenance_mode_allows_admin_api_test() {
  let config = availability_config(availability_mode.MaintenanceMode)

  assert run_policy_program(
      availability_policy_domain.enforce_api_action(api_action.admin(
        admin_action.GetAdminDebugConfigAction,
      )),
      config,
    )
    == Ok(Nil)
}

pub fn read_only_mode_keeps_general_pages_available_test() {
  let config = availability_config(availability_mode.ReadOnlyMode)

  assert run_policy_program(
      availability_policy_domain.evaluate_page_route(
        route.Public(route.Snippets(
          after: option.None,
          before: option.None,
          username: option.None,
        )),
      ),
      config,
    )
    == Ok(availability_policy_domain.AllowPage)
}

pub fn maintenance_mode_blocks_general_pages_test() {
  let config = availability_config(availability_mode.MaintenanceMode)

  assert run_policy_program(
      availability_policy_domain.evaluate_page_route(route.Account(
        route.AccountHome,
      )),
      config,
    )
    == Ok(availability_policy_domain.UnavailablePage(
      message: config.message,
      retry_after_seconds: config.retry_after_seconds,
    ))
}

pub fn maintenance_mode_keeps_login_admin_and_not_found_pages_available_test() {
  let config = availability_config(availability_mode.MaintenanceMode)
  let assert Ok(not_found_uri) = uri.parse("/missing")

  assert run_policy_program(
      availability_policy_domain.evaluate_page_route(route.Public(route.Login)),
      config,
    )
    == Ok(availability_policy_domain.AllowPage)
  assert run_policy_program(
      availability_policy_domain.evaluate_page_route(route.Admin(
        route.AdminHome,
      )),
      config,
    )
    == Ok(availability_policy_domain.AllowPage)
  assert run_policy_program(
      availability_policy_domain.evaluate_page_route(route.NotFound(
        not_found_uri,
      )),
      config,
    )
    == Ok(availability_policy_domain.AllowPage)
}

fn run_policy_program(
  program: program_types.Program(a),
  config: dynamic_config.AvailabilityConfig,
) -> Result(a, error.Error) {
  case program {
    program_types.Pure(value) -> Ok(value)
    program_types.Fail(err) -> Error(err)
    program_types.Impure(program_types.AppConfigEffect(effect)) ->
      run_policy_program(run_app_config_effect(effect, config), config)
    program_types.Impure(_) ->
      panic as "availability policy test encountered unexpected effect"
    program_types.Attempt(program:, on_error:) ->
      case run_policy_program(program, config) {
        Ok(value) -> Ok(value)
        Error(err) -> run_policy_program(on_error(err), config)
      }
  }
}

fn run_app_config_effect(
  effect: app_config_algebra.AppConfigEffect(program_types.Program(a)),
  config: dynamic_config.AvailabilityConfig,
) -> program_types.Program(a) {
  case effect {
    app_config_algebra.GetDynamicConfig(next:) ->
      next(
        Ok(dynamic_config.DynamicConfig(
          debug: dynamic_config.DebugConfig(enabled: False),
          availability: config,
          auth: dynamic_config.AuthConfig(
            login_token_max_age: 900,
            session_token_max_age: 86_400,
            session_cookie_max_age: 86_400,
            session_refresh_interval_seconds: 300,
            session_previous_token_grace_seconds: 60,
            session_heartbeat_interval_seconds: 60,
          ),
          cleanup: dynamic_config.CleanupConfig(
            api_log_retention_days: 30,
            page_log_retention_days: 30,
            pageview_log_retention_days: 30,
            run_log_retention_days: 90,
            job_log_retention_days: 90,
            jobs_retention_days: 90,
            login_tokens_retention_days: 30,
            user_actions_retention_days: 90,
          ),
          docker_run: option.None,
          rate_limit_policies: dict.new(),
        )),
      )
    _ ->
      panic as "availability policy test encountered unexpected app_config effect"
  }
}

fn availability_config(
  mode: availability_mode.AvailabilityMode,
) -> dynamic_config.AvailabilityConfig {
  dynamic_config.AvailabilityConfig(
    mode: mode,
    message: "Scheduled platform maintenance.",
    retry_after_seconds: option.Some(600),
  )
}
