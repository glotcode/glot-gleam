import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/effect/run_log/run_log_algebra
import glot_backend/erlang

pub fn run(
  effect: run_log_algebra.RunLogEffect(next_program),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    run_log_algebra.CreateRunLog(run_log:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.run_log.create_run_log(run_log)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.RunLogEffectName(run_log_algebra.CreateRunLogEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    run_log_algebra.DeleteRunLogBefore(before:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.run_log.delete_before(before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.RunLogEffectName(
            run_log_algebra.DeleteRunLogBeforeEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}
