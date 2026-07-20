import exception
import glot_backend/system/effect/error
import glot_backend/system/effect/interpreter
import glot_backend/system/effect/program_types
import glot_backend/system/effect/runtime
import glot_backend/system/effect/service_ports.{type ServicePorts}
import glot_backend/system/request/context
import support/integration/adapter/state
import support/integration/model

pub fn run_test_program_with(
  program: program_types.Program(a),
  ctx: context.Context,
  initial: model.TestState,
  build_services: fn(state.State) -> ServicePorts,
) -> #(Result(a, error.Error), model.TestState) {
  let test_state = state.new(initial)
  use <- exception.defer(fn() { state.stop(test_state) })
  let effect_runtime = runtime.new(build_services(test_state))
  let #(result, _) = interpreter.run(program, effect_runtime, ctx)
  #(result, state.get(test_state))
}
