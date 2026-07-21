import gleam/option
import glot_frontend/api/response
import glot_frontend/public/contact/command
import glot_frontend/public/contact/managed
import glot_frontend/public/contact/message
import glot_frontend/public/contact/model as contact_model
import glot_frontend/public/contact/page
import support/managed_scenario

type Scenario =
  managed_scenario.Scenario(
    contact_model.Model,
    command.Command(message.Msg),
    Nil,
  )

pub fn contact_submission_is_driven_by_a_typed_fixture_test() {
  let scenario = start()
  let scenario = dispatch(scenario, message.EmailChanged("fixture@example.com"))
  let scenario = dispatch(scenario, message.TopicChanged("privacy"))
  let scenario =
    dispatch(
      scenario,
      message.MessageChanged("A fixture-driven integration message."),
    )
  let scenario = dispatch(scenario, message.SubmittedForm)
  let assert [submit_command] = managed_scenario.pending(scenario)
  let assert command.Submit(request, complete) = submit_command
  assert request.email == "fixture@example.com"
  assert request.message == "A fixture-driven integration message."

  let scenario =
    managed_scenario.replace_pending(scenario, [])
    |> dispatch(complete(response.Success(Nil)))
  let model = managed_scenario.model(scenario)
  assert model.status == contact_model.Submitted
  assert model.message == ""
  managed_scenario.assert_no_pending(scenario)
}

fn start() -> Scenario {
  managed_scenario.start(managed.init(option.None), command.None, interpret)
}

fn dispatch(scenario: Scenario, msg: message.Msg) -> Scenario {
  managed_scenario.dispatch(scenario, msg, page.update_managed, interpret)
}

fn interpret(scenario: Scenario, next_command: command.Command(message.Msg)) {
  case next_command {
    command.None -> scenario
    _ -> managed_scenario.append_pending(scenario, next_command)
  }
}
