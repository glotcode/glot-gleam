import gleam/option
import gleam/regexp
import glot_core/email/email_address_model
import glot_frontend/api/response
import glot_frontend/app/event as app_event
import glot_frontend/public/login/command
import glot_frontend/public/login/message
import glot_frontend/public/login/model as login_model
import glot_frontend/public/login/page
import support/managed_scenario
import youid/uuid

type Scenario =
  managed_scenario.Scenario(
    login_model.Model,
    command.Command(message.Msg),
    app_event.AppEvent,
  )

pub fn initialization_detects_passkey_support_through_a_command_test() {
  let #(model, initial_command) = page.init_managed()
  assert !model.passkey_supported
  let scenario = managed_scenario.start(model, initial_command, interpret)
  let assert [command.DetectPasskeySupport(complete)] =
    managed_scenario.pending(scenario)

  let scenario = respond(scenario, complete(True))
  let model = managed_scenario.model(scenario)

  assert model.passkey_supported
  managed_scenario.assert_no_pending(scenario)
  assert managed_scenario.observed(scenario) == []
}

pub fn email_submission_is_exposed_as_a_typed_fixture_boundary_test() {
  let #(model, _) = page.init_managed()
  let scenario = managed_scenario.new(model)
  let scenario = dispatch(scenario, message.EmailChanged("person@example.com"))
  let scenario = dispatch(scenario, message.SendTokenSubmitted)
  let assert [request_command] = managed_scenario.pending(scenario)
  let assert command.SendLoginToken(email, complete) = request_command
  assert email_address_model.to_string(email) == "person@example.com"

  let scenario = respond(scenario, complete(response.Success(Nil)))
  let model = managed_scenario.model(scenario)
  let assert login_model.EnterToken(sent_to) = model.step
  assert email_address_model.to_string(sent_to) == "person@example.com"
  managed_scenario.assert_no_pending(scenario)
}

pub fn email_submission_covers_validation_failure_and_retry_test() {
  let #(model, _) = page.init_managed()
  let invalid =
    managed_scenario.new(model)
    |> dispatch(message.EmailChanged("not-an-email"))
    |> dispatch(message.SendTokenSubmitted)
  assert managed_scenario.pending(invalid) == []
  assert invalid |> managed_scenario.model |> fn(model) { model.status }
    == login_model.StatusError("Please enter a valid email address.")

  let scenario =
    invalid
    |> dispatch(message.EmailChanged("person@example.com"))
    |> dispatch(message.SendTokenSubmitted)
  let assert [command.SendLoginToken(_, complete)] =
    managed_scenario.pending(scenario)
  let scenario = respond(scenario, complete(api_failure("Email rejected.")))
  assert scenario |> managed_scenario.model |> fn(model) { model.status }
    == login_model.StatusError(
      "Email rejected. Request ID: 00000000-0000-4000-8000-000000000096",
    )

  let scenario = dispatch(scenario, message.SendTokenSubmitted)
  let assert [command.SendLoginToken(_, retry)] =
    managed_scenario.pending(scenario)
  let scenario = respond(scenario, retry(response.Success(Nil)))
  let assert login_model.EnterToken(_) = managed_scenario.model(scenario).step
}

pub fn successful_login_exposes_navigation_and_session_refresh_test() {
  let assert Ok(email_pattern) = regexp.from_string(email_address_model.pattern)
  let assert option.Some(email) =
    email_address_model.from_string(email_pattern, "person@example.com")
  let model =
    login_model.Model(
      email: "person@example.com",
      token: "fixture-token",
      step: login_model.EnterToken(email),
      status: login_model.LoggingIn,
      passkey_supported: False,
      passkey_challenge_id: option.None,
      passkey_status: login_model.PasskeyIdle,
    )

  let scenario =
    managed_scenario.new(model)
    |> dispatch(message.LoggedIn(response.Success(Nil)))
  let model = managed_scenario.model(scenario)

  assert model.status == login_model.StatusInfo("You are now logged in.")
  assert managed_scenario.pending(scenario) == [command.NavigateReplace("/")]
  assert managed_scenario.observed(scenario) == [app_event.RefreshSession]
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
    _ -> managed_scenario.append_pending(scenario, next_command)
  }
}

fn api_failure(message: String) -> response.Response(value) {
  let assert Ok(id) = uuid.from_string("00000000-0000-4000-8000-000000000096")
  response.ApiFailure(response.Error("fixture", message, id))
}
