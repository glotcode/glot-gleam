import gleam/list

/// Shared state machine used by managed-effect integration tests.
///
/// Feature adapters decide how their command algebra is interpreted. This
/// kernel owns the common bookkeeping: current model state, pending fixture
/// work, observed external effects, dispatch, and synchronous command chains.
pub opaque type Scenario(model, pending, observed) {
  Scenario(model: model, pending: List(pending), observed: List(observed))
}

pub fn new(model: model) -> Scenario(model, pending, observed) {
  Scenario(model:, pending: [], observed: [])
}

pub fn model(scenario: Scenario(model, pending, observed)) -> model {
  scenario.model
}

pub fn pending(scenario: Scenario(model, pending, observed)) -> List(pending) {
  scenario.pending
}

pub fn observed(
  scenario: Scenario(model, pending, observed),
) -> List(observed) {
  scenario.observed
}

pub fn replace_model(
  scenario: Scenario(model, pending, observed),
  model: model,
) -> Scenario(model, pending, observed) {
  Scenario(..scenario, model: model)
}

pub fn replace_pending(
  scenario: Scenario(model, pending, observed),
  pending: List(pending),
) -> Scenario(model, pending, observed) {
  Scenario(..scenario, pending: pending)
}

pub fn append_pending(
  scenario: Scenario(model, pending, observed),
  effect: pending,
) -> Scenario(model, pending, observed) {
  Scenario(..scenario, pending: list.append(scenario.pending, [effect]))
}

pub fn append_observed(
  scenario: Scenario(model, pending, observed),
  effect: observed,
) -> Scenario(model, pending, observed) {
  Scenario(..scenario, observed: list.append(scenario.observed, [effect]))
}

pub fn take_next_pending(
  scenario: Scenario(model, pending, observed),
) -> #(pending, Scenario(model, pending, observed)) {
  take_pending_at(scenario, 0)
}

pub fn take_pending_at(
  scenario: Scenario(model, pending, observed),
  index: Int,
) -> #(pending, Scenario(model, pending, observed)) {
  let #(before, selected_and_after) = list.split(scenario.pending, index)
  let assert [selected, ..after] = selected_and_after
  #(selected, Scenario(..scenario, pending: list.append(before, after)))
}

pub fn start(
  model: model,
  initial_command: command,
  interpret: fn(Scenario(model, pending, observed), command) ->
    Scenario(model, pending, observed),
) -> Scenario(model, pending, observed) {
  interpret(new(model), initial_command)
}

pub fn dispatch(
  scenario: Scenario(model, pending, observed),
  message: message,
  update: fn(model, message) -> #(model, command),
  interpret: fn(Scenario(model, pending, observed), command) ->
    Scenario(model, pending, observed),
) -> Scenario(model, pending, observed) {
  let #(next_model, next_command) = update(scenario.model, message)
  interpret(Scenario(..scenario, model: next_model), next_command)
}

pub fn assert_no_pending(scenario: Scenario(model, pending, observed)) -> Nil {
  let assert [] = scenario.pending
  Nil
}
