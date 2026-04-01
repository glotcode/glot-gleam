import gleam/int
import gleam/list
import glot_backend/effect/auth/auth_interpreter
import glot_backend/effect/core/core_interpreter
import glot_backend/effect/docker_run/docker_run_interpreter
import glot_backend/effect/error
import glot_backend/effect/runtime_types
import glot_backend/effect/snippet/snippet_interpreter
import glot_backend/effect/transaction/transaction_interpreter
import glot_backend/effect/types
import glot_backend/erlang

pub fn run(
  effect: types.Program(a),
  handlers: runtime_types.Handlers,
) -> #(Result(a, error.Error), types.State) {
  let #(result, state) = run_with_state(effect, handlers, types.new_state())
  #(result, types.State(..state, effect_timings: list.reverse(state.effect_timings)))
}

fn run_with_state(
  effect: types.Program(a),
  handlers: runtime_types.Handlers,
  state: types.State,
) -> #(Result(a, error.Error), types.State) {
  let continue = fn(next_effect, next_state) {
    run_with_state(next_effect, handlers, next_state)
  }

  case effect {
    types.Pure(value) -> #(Ok(value), state)
    types.Fail(error) -> #(Error(error), state)
    types.Impure(effect) ->
      case effect {
        types.CoreEffect(effect) ->
          core_interpreter.run(effect, handlers, state, continue, measure_effect)
        types.AuthEffect(effect) ->
          auth_interpreter.run(effect, handlers, state, continue, measure_effect)
        types.SnippetEffect(effect) ->
          snippet_interpreter.run(effect, handlers, state, continue, measure_effect)
        types.DockerRunEffect(effect) ->
          docker_run_interpreter.run(
            effect,
            handlers,
            state,
            continue,
            measure_effect,
          )
        types.TransactionEffect(commands, next) ->
          transaction_interpreter.run(
            commands,
            next,
            handlers,
            state,
            continue,
            measure_effect,
          )
      }
  }
}

fn measure_effect(
  state: types.State,
  effect_name: types.EffectName,
  started_at_ns: Int,
) -> types.State {
  let elapsed_ns = erlang.perf_counter_ns() - started_at_ns
  let safe_elapsed_ns = int.max(elapsed_ns, 0)
  types.add_effect_timings(state, effect_name, safe_elapsed_ns)
}
