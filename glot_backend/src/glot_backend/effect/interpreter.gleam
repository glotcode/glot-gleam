import gleam/int
import gleam/list
import glot_backend/effect/auth/auth_interpreter
import glot_backend/effect/core/core_interpreter
import glot_backend/effect/docker_run/docker_run_interpreter
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/effect/snippet/snippet_interpreter
import glot_backend/effect/transaction/transaction_interpreter
import glot_backend/erlang

pub fn run(
  effect: effect_model.Program(a),
  handlers: handlers_types.Handlers,
) -> #(Result(a, error.Error), effect_model.State) {
  let #(result, state) =
    run_with_state(effect, handlers, effect_model.new_state())
  #(result, effect_model.State(..state, effect_timings: list.reverse(state.effect_timings)))
}

fn run_with_state(
  effect: effect_model.Program(a),
  handlers: handlers_types.Handlers,
  state: effect_model.State,
) -> #(Result(a, error.Error), effect_model.State) {
  let continue = fn(next_effect, next_state) {
    run_with_state(next_effect, handlers, next_state)
  }

  case effect {
    effect_model.Pure(value) -> #(Ok(value), state)
    effect_model.Fail(error) -> #(Error(error), state)
    effect_model.Impure(effect) ->
      case effect {
        effect_model.CoreEffect(effect) ->
          core_interpreter.run(effect, handlers, state, continue, measure_effect)
        effect_model.AuthEffect(effect) ->
          auth_interpreter.run(effect, handlers, state, continue, measure_effect)
        effect_model.SnippetEffect(effect) ->
          snippet_interpreter.run(effect, handlers, state, continue, measure_effect)
        effect_model.DockerRunEffect(effect) ->
          docker_run_interpreter.run(
            effect,
            handlers,
            state,
            continue,
            measure_effect,
          )
        effect_model.TransactionEffect(commands, next) ->
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
  state: effect_model.State,
  effect_name: effect_model.EffectName,
  started_at_ns: Int,
) -> effect_model.State {
  let elapsed_ns = erlang.perf_counter_ns() - started_at_ns
  let safe_elapsed_ns = int.max(elapsed_ns, 0)
  effect_model.add_effect_timings(state, effect_name, safe_elapsed_ns)
}
