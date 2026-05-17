import gleam/option
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/error
import glot_backend/effect/error/policy_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/api_action
import glot_core/availability_mode
import glot_core/public_action
import glot_core/route

pub type PageAvailabilityDecision {
  AllowPage
  UnavailablePage(message: String, retry_after_seconds: option.Option(Int))
}

type ApiSurface {
  AdminApiSurface
  AuthenticationApiSurface
  PublicReadApiSurface
  PublicWriteApiSurface
}

type PageSurface {
  AdminPageSurface
  LoginPageSurface
  GeneralPageSurface
  NotFoundPageSurface
}

pub fn enforce_api_action(
  action: api_action.ApiAction,
) -> program_types.Program(Nil) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let availability = dynamic_config.availability_config(config)

  case api_action_error(availability, action) {
    option.Some(err) -> program.fail(error.policy(err))
    option.None -> program.succeed(Nil)
  }
}

pub fn evaluate_page_route(
  page_route: route.Route,
) -> program_types.Program(PageAvailabilityDecision) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let availability = dynamic_config.availability_config(config)
  let surface = page_surface(page_route)

  case page_surface_allowed_in_mode(availability.mode, surface) {
    True -> program.succeed(AllowPage)
    False ->
      program.succeed(UnavailablePage(
        message: availability.message,
        retry_after_seconds: availability.retry_after_seconds,
      ))
  }
}

fn api_action_error(
  availability: dynamic_config.AvailabilityConfig,
  action: api_action.ApiAction,
) -> option.Option(policy_error.PolicyError) {
  let surface = api_surface(action)

  case
    availability.mode,
    api_surface_allowed_in_mode(availability.mode, surface)
  {
    availability_mode.NormalMode, _ -> option.None
    _, True -> option.None
    availability_mode.ReadOnlyMode, False ->
      option.Some(policy_error.ReadOnlyModeBlocked(
        message: availability.message,
        retry_after_seconds: availability.retry_after_seconds,
      ))
    availability_mode.MaintenanceMode, False ->
      option.Some(policy_error.MaintenanceModeBlocked(
        message: availability.message,
        retry_after_seconds: availability.retry_after_seconds,
      ))
  }
}

fn api_surface(action: api_action.ApiAction) -> ApiSurface {
  case action {
    api_action.AdminAction(_) -> AdminApiSurface
    api_action.PublicAction(public_action.TrackPageviewAction) ->
      AuthenticationApiSurface
    api_action.PublicAction(public_action.GetSessionAction) ->
      AuthenticationApiSurface
    api_action.PublicAction(public_action.LogoutAction) ->
      AuthenticationApiSurface
    api_action.PublicAction(public_action.SendLoginTokenAction) ->
      AuthenticationApiSurface
    api_action.PublicAction(public_action.LoginAction) ->
      AuthenticationApiSurface
    api_action.PublicAction(public_action.RunAction) -> PublicReadApiSurface
    api_action.PublicAction(public_action.GetLanguageVersionAction) ->
      PublicReadApiSurface
    api_action.PublicAction(public_action.GetAccountAction) ->
      PublicReadApiSurface
    api_action.PublicAction(public_action.GetSnippetAction) ->
      PublicReadApiSurface
    api_action.PublicAction(public_action.ListPublicSnippetsAction) ->
      PublicReadApiSurface
    api_action.PublicAction(public_action.ListSessionSnippetsAction) ->
      PublicReadApiSurface
    api_action.PublicAction(_) -> PublicWriteApiSurface
  }
}

fn api_surface_allowed_in_mode(
  mode: availability_mode.AvailabilityMode,
  surface: ApiSurface,
) -> Bool {
  case mode, surface {
    availability_mode.NormalMode, _ -> True
    availability_mode.ReadOnlyMode, AdminApiSurface -> True
    availability_mode.ReadOnlyMode, AuthenticationApiSurface -> True
    availability_mode.ReadOnlyMode, PublicReadApiSurface -> True
    availability_mode.ReadOnlyMode, PublicWriteApiSurface -> False
    availability_mode.MaintenanceMode, AdminApiSurface -> True
    availability_mode.MaintenanceMode, AuthenticationApiSurface -> True
    availability_mode.MaintenanceMode, PublicReadApiSurface -> False
    availability_mode.MaintenanceMode, PublicWriteApiSurface -> False
  }
}

fn page_surface(page_route: route.Route) -> PageSurface {
  case page_route {
    route.Admin(_) -> AdminPageSurface
    route.Public(route.Login) -> LoginPageSurface
    route.NotFound(_) -> NotFoundPageSurface
    route.Public(_) | route.Account(_) -> GeneralPageSurface
  }
}

fn page_surface_allowed_in_mode(
  mode: availability_mode.AvailabilityMode,
  surface: PageSurface,
) -> Bool {
  case mode, surface {
    availability_mode.NormalMode, _ -> True
    availability_mode.ReadOnlyMode, _ -> True
    availability_mode.MaintenanceMode, AdminPageSurface -> True
    availability_mode.MaintenanceMode, LoginPageSurface -> True
    availability_mode.MaintenanceMode, NotFoundPageSurface -> True
    availability_mode.MaintenanceMode, GeneralPageSurface -> False
  }
}
