import gleam/list
import glot_backend/effect/auth/auth_interpreter
import glot_backend/effect/core/core_interpreter
import glot_backend/effect/docker_run/docker_run_interpreter
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/job/job_interpreter
import glot_backend/effect/program_state
import glot_backend/effect/runtime
import glot_backend/effect/snippet/snippet_interpreter
import glot_backend/erlang

pub fn run(
  effect: effect_model.Program(a),
  handlers: handlers.Handlers,
  runtime: runtime.Runtime,
) -> #(Result(a, error.Error), program_state.State) {
  let #(result, state) =
    run_with_state(effect, handlers, runtime, program_state.new_state())
  #(
    result,
    program_state.State(
      ..state,
      effect_measurements: list.reverse(state.effect_measurements),
    ),
  )
}

fn run_with_state(
  effect: effect_model.Program(a),
  handlers: handlers.Handlers,
  runtime: runtime.Runtime,
  state: program_state.State,
) -> #(Result(a, error.Error), program_state.State) {
  let continue = fn(next_effect, next_state) {
    run_with_state(next_effect, handlers, runtime, next_state)
  }

  case effect {
    effect_model.Pure(value) -> #(Ok(value), state)
    effect_model.Fail(error) -> #(Error(error), state)
    effect_model.Impure(effect) ->
      case effect {
        effect_model.CoreEffect(effect) ->
          core_interpreter.run(effect, handlers, state, continue)
        effect_model.JobEffect(effect) ->
          job_interpreter.run(effect, handlers, state, continue)
        effect_model.AuthEffect(effect) ->
          auth_interpreter.run(effect, handlers, state, continue)
        effect_model.SnippetEffect(effect) ->
          snippet_interpreter.run(effect, handlers, state, continue)
        effect_model.DockerRunEffect(effect) ->
          docker_run_interpreter.run(effect, handlers, state, continue)
        effect_model.TransactionEffect(sub_effects, next) -> {
          let started_at = erlang.perf_counter_ns()
          let #(transaction_result, transaction_state) =
            runtime.run_in_transaction(sub_effects)
          continue(
            next(transaction_result),
            program_state.add_effect_measurement(
              state,
              effect_model.RunInTransactionEffectName(
                transaction_state.effect_measurements,
              ),
              effect_model.DbWriteEffectCategory,
              started_at,
            ),
          )
        }
      }
  }
}
