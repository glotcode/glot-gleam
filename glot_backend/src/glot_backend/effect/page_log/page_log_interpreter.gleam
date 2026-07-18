import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/page_log/page_log_algebra
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: page_log_algebra.PageLogEffect(next_program),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    page_log_algebra.DeletePageLogBefore(before:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.page_log.delete_before(before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.PageLogEffectName(
            page_log_algebra.DeletePageLogBeforeEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}
