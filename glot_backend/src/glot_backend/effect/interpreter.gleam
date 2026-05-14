import gleam/list
import glot_backend/context
import glot_backend/effect/app_config/app_config_interpreter
import glot_backend/effect/basic/basic_interpreter
import glot_backend/effect/db_interpreter
import glot_backend/effect/docker_run/docker_run_interpreter
import glot_backend/effect/email/email_interpreter
import glot_backend/effect/error
import glot_backend/effect/get_language_version/get_language_version_interpreter
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/effect/transaction/transaction_interpreter

pub fn run(
  effect: program_types.Program(a),
  runtime: runtime.Runtime,
  ctx: context.Context,
) -> #(Result(a, error.Error), program_state.State) {
  let #(result, state) =
    run_with_state(effect, runtime, ctx, program_state.new_state())
  #(
    result,
    program_state.State(
      ..state,
      effect_measurements: list.reverse(state.effect_measurements),
    ),
  )
}

pub fn run_with_state(
  effect: program_types.Program(a),
  runtime: runtime.Runtime,
  ctx: context.Context,
  state: program_state.State,
) -> #(Result(a, error.Error), program_state.State) {
  let continue = fn(next_effect, next_state) {
    run_with_state(next_effect, runtime, ctx, next_state)
  }

  case effect {
    program_types.Pure(value) -> #(Ok(value), state)
    program_types.Fail(error) -> #(Error(error), state)
    program_types.Impure(effect) ->
      run_effect(effect, runtime, ctx, state, continue)
    program_types.Attempt(program:, on_error:) ->
      case run_with_state(program, runtime, ctx, state) {
        #(Ok(value), next_state) -> #(Ok(value), next_state)
        #(Error(err), next_state) ->
          run_with_state(on_error(err), runtime, ctx, next_state)
      }
  }
}

fn run_effect(
  effect: program_types.Effect(program_types.Program(a)),
  runtime: runtime.Runtime,
  ctx: context.Context,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    program_types.AppConfigEffect(effect) ->
      app_config_interpreter.run(effect, runtime, state, continue)
    program_types.BasicEffect(effect) ->
      basic_interpreter.run(effect, ctx, runtime, state, continue)
    program_types.EmailEffect(effect) ->
      email_interpreter.run(effect, ctx, runtime.handlers, state, continue)
    program_types.DockerRunEffect(effect) ->
      docker_run_interpreter.run(effect, runtime, ctx, state, continue)
    program_types.GetLanguageVersionEffect(effect) ->
      get_language_version_interpreter.run(
        effect,
        runtime,
        ctx,
        state,
        continue,
      )
    program_types.DbEffect(effect) ->
      db_interpreter.run(effect, ctx, runtime.handlers, state, continue)
    program_types.TransactionEffect(effect) ->
      transaction_interpreter.run(effect, runtime, ctx, state, continue)
  }
}
