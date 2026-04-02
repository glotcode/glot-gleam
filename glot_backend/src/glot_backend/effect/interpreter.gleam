import gleam/list
import gleam/option
import glot_backend/context
import glot_backend/effect/auth/auth_interpreter
import glot_backend/effect/basic/basic_interpreter
import glot_backend/effect/docker_run/docker_run_interpreter
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/job/job_interpreter
import glot_backend/effect/program_types
import glot_backend/effect/program_state
import glot_backend/effect/snippet/snippet_interpreter
import glot_backend/effect/user_action/user_action_interpreter
import glot_backend/erlang
import pog

pub fn run(
  effect: program_types.Program(a),
  handlers: handlers.Handlers,
  maybe_db: option.Option(pog.Connection),
  ctx: context.Context,
) -> #(Result(a, error.Error), program_state.State) {
  let #(result, state) =
    run_with_state(effect, handlers, maybe_db, ctx, program_state.new_state())
  #(
    result,
    program_state.State(
      ..state,
      effect_measurements: list.reverse(state.effect_measurements),
    ),
  )
}

fn run_with_state(
  effect: program_types.Program(a),
  handlers: handlers.Handlers,
  maybe_db: option.Option(pog.Connection),
  ctx: context.Context,
  state: program_state.State,
) -> #(Result(a, error.Error), program_state.State) {
  let continue = fn(next_effect, next_state) {
    run_with_state(next_effect, handlers, maybe_db, ctx, next_state)
  }

  case effect {
    program_types.Pure(value) -> #(Ok(value), state)
    program_types.Fail(error) -> #(Error(error), state)
    program_types.Impure(effect) ->
      case effect {
        program_types.BasicEffect(effect) ->
          basic_interpreter.run(effect, ctx, handlers, state, continue)
        program_types.JobEffect(effect) ->
          job_interpreter.run(effect, handlers, state, continue)
        program_types.AuthEffect(effect) ->
          auth_interpreter.run(effect, ctx, handlers, state, continue)
        program_types.SnippetEffect(effect) ->
          snippet_interpreter.run(effect, handlers, state, continue)
        program_types.DockerRunEffect(effect) ->
          docker_run_interpreter.run(effect, handlers, state, continue)
        program_types.UserActionEffect(effect) ->
          user_action_interpreter.run(effect, handlers, state, continue)
        program_types.TransactionEffect(run) -> {
          let started_at = erlang.perf_counter_ns()
          case maybe_db {
            option.Some(db) -> {
              let #(next_effect, transaction_state) = run(db, ctx)
              continue(
                next_effect,
                program_state.add_effect_measurement(
                  state,
                  effect_trace.RunInTransactionEffectName(
                    transaction_state.effect_measurements,
                  ),
                  effect_trace.DbWriteEffectCategory,
                  started_at,
                ),
              )
            }
            option.None -> #(
              Error(error.TransactionError(error.DbTransactionError("Missing transaction db"))),
              program_state.add_effect_measurement(
                state,
                effect_trace.RunInTransactionEffectName([]),
                effect_trace.DbWriteEffectCategory,
                started_at,
              ),
            )
          }
        }
      }
  }
}
