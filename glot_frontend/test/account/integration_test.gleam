import gleam/list
import gleam/option
import gleam/regexp
import glot_core/auth/account_dto
import glot_core/email/email_address_model
import glot_core/helpers/timestamp_helpers
import glot_core/loadable
import glot_frontend/account/command
import glot_frontend/account/message
import glot_frontend/account/model as account_model
import glot_frontend/account/page
import glot_frontend/api/response
import glot_frontend/app/event as app_event
import support/managed_scenario
import youid/uuid

type Scenario =
  managed_scenario.Scenario(
    account_model.Model,
    command.Command(message.Msg),
    app_event.AppEvent,
  )

pub fn initialization_and_account_api_are_fixture_driven_test() {
  let #(model, initial_command) = page.init_managed()
  let scenario = managed_scenario.start(model, initial_command, interpret)
  let assert [command.DetectPasskeySupport(runtime_loaded)] =
    managed_scenario.pending(scenario)

  let scenario = respond(scenario, runtime_loaded(False))
  let assert [
    command.GetAccount(account_loaded),
    command.GetSession(_),
    command.ListSessions(_),
    command.Schedule(_, _),
    command.Schedule(_, _),
  ] = managed_scenario.pending(scenario)

  let fixture = account_fixture()
  let scenario = respond(scenario, account_loaded(response.Success(fixture)))
  let model = managed_scenario.model(scenario)

  assert model.account == loadable.Loaded(fixture)
  assert model.username == "fixture-user"
}

pub fn logout_fixture_drives_navigation_and_session_refresh_test() {
  let #(model, _) = page.init_managed()
  let scenario = managed_scenario.new(model)
  let scenario = dispatch(scenario, message.LogoutSubmitted)
  let assert [logout_command] = managed_scenario.pending(scenario)
  let assert command.Logout(complete) = logout_command

  let scenario = respond(scenario, complete(response.Success(Nil)))

  assert managed_scenario.pending(scenario) == [command.NavigateReplace("/")]
  assert managed_scenario.observed(scenario) == [app_event.RefreshSession]
}

pub fn session_deletion_covers_failure_retry_and_success_test() {
  let #(model, _) = page.init_managed()
  let id = uuid.v7()
  let scenario =
    managed_scenario.new(model)
    |> dispatch(message.DeleteSessionSubmitted(id))
  let assert [command.DeleteSession(request, complete)] =
    managed_scenario.pending(scenario)
  assert request.id == id

  let scenario = respond(scenario, complete(api_failure("Session rejected.")))
  assert managed_scenario.model(scenario).sessions_status
    == account_model.SessionsError(
      "Session rejected. Request ID: 00000000-0000-4000-8000-000000000098",
    )

  let scenario = dispatch(scenario, message.DeleteSessionSubmitted(id))
  let assert [command.DeleteSession(_, retry)] =
    managed_scenario.pending(scenario)
  let scenario = respond(scenario, retry(response.Success(Nil)))
  let assert [
    command.GetSession(_),
    command.ListSessions(_),
    command.Schedule(_, _),
  ] = managed_scenario.pending(scenario)
  assert managed_scenario.observed(scenario) == [app_event.RefreshSession]
}

pub fn passkey_deletion_covers_failure_retry_and_success_test() {
  let #(model, _) = page.init_managed()
  let id = uuid.v7()
  let scenario =
    managed_scenario.new(model)
    |> dispatch(message.DeletePasskeySubmitted(id))
  let assert [command.DeletePasskey(request, complete)] =
    managed_scenario.pending(scenario)
  assert request.id == id

  let scenario = respond(scenario, complete(api_failure("Passkey rejected.")))
  assert managed_scenario.model(scenario).passkeys_status
    == account_model.PasskeysError(
      "Passkey rejected. Request ID: 00000000-0000-4000-8000-000000000098",
    )

  let scenario = dispatch(scenario, message.DeletePasskeySubmitted(id))
  let assert [command.DeletePasskey(_, retry)] =
    managed_scenario.pending(scenario)
  let scenario = respond(scenario, retry(response.Success(Nil)))
  let assert [command.ListPasskeys(_), command.Schedule(_, _)] =
    managed_scenario.pending(scenario)
  assert managed_scenario.model(scenario).passkeys_status
    == account_model.LoadingPasskeys
}

fn respond(scenario: Scenario, msg: message.Msg) -> Scenario {
  let #(_, scenario) = managed_scenario.take_next_pending(scenario)
  dispatch(scenario, msg)
}

fn dispatch(scenario: Scenario, msg: message.Msg) -> Scenario {
  let #(model, next_command, event) =
    page.update_managed(managed_scenario.model(scenario), msg)
  let scenario = managed_scenario.replace_model(scenario, model)
  let scenario = interpret(scenario, next_command)
  case event {
    app_event.NoAppEvent -> scenario
    _ -> managed_scenario.append_observed(scenario, event)
  }
}

fn interpret(scenario: Scenario, next_command: command.Command(message.Msg)) {
  case next_command {
    command.None -> scenario
    command.Batch(commands) -> list.fold(commands, scenario, interpret)
    _ -> managed_scenario.append_pending(scenario, next_command)
  }
}

fn account_fixture() -> account_dto.AccountResponse {
  let assert Ok(id) = uuid.from_string("00000000-0000-4000-8000-000000000003")
  let assert Ok(email_pattern) = regexp.from_string(email_address_model.pattern)
  let assert option.Some(email) =
    email_address_model.from_string(email_pattern, "fixture@example.com")
  account_dto.AccountResponse(
    id: id,
    email: email,
    username: "fixture-user",
    delete_scheduled: False,
    delete_scheduled_at: option.None,
    joined_at: timestamp_helpers.from_unix_milliseconds(0),
  )
}

fn api_failure(message: String) -> response.Response(value) {
  let assert Ok(id) = uuid.from_string("00000000-0000-4000-8000-000000000098")
  response.ApiFailure(response.Error("fixture", message, id))
}
