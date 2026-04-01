import gleam/list
import glot_backend/effect/auth/auth_interpreter
import glot_backend/effect/core/core_interpreter
import glot_backend/effect/docker_run/docker_run_interpreter
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/effect/program_state
import glot_backend/effect/snippet/snippet_interpreter
import glot_backend/effect/transaction/transaction_interpreter

pub fn run(
  effect: effect_model.Program(a),
  handlers: handlers_types.Handlers,
) -> #(Result(a, error.Error), program_state.State) {
  let #(result, state) =
    run_with_state(effect, handlers, program_state.new_state())
  #(
    result,
    program_state.State(
      ..state,
      effect_timings: list.reverse(state.effect_timings),
    ),
  )
}

fn run_with_state(
  effect: effect_model.Program(a),
  handlers: handlers_types.Handlers,
  state: program_state.State,
) -> #(Result(a, error.Error), program_state.State) {
  let continue = fn(next_effect, next_state) {
    run_with_state(next_effect, handlers, next_state)
  }

  case effect {
    effect_model.Pure(value) -> #(Ok(value), state)
    effect_model.Fail(error) -> #(Error(error), state)
    effect_model.Impure(effect) ->
      case effect {
        effect_model.CoreEffect(effect) ->
          core_interpreter.run(effect, handlers, state, continue)
        effect_model.AuthEffect(effect) ->
          auth_interpreter.run(effect, handlers, state, continue)
        effect_model.SnippetEffect(effect) ->
          snippet_interpreter.run(effect, handlers, state, continue)
        effect_model.DockerRunEffect(effect) ->
          docker_run_interpreter.run(effect, handlers, state, continue)
        effect_model.TransactionEffect(sub_effects, next) ->
          transaction_interpreter.run(
            sub_effects,
            next,
            handlers,
            state,
            continue,
          )
      }
  }
}
