import glot_backend/logging/effect/algebra as logging_algebra
import glot_backend/logging/page_log/effect/algebra as page_log_algebra
import glot_backend/logging/page_log/ports/store.{type Store}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: page_log_algebra.PageLogEffect(next_program),
  store: Store,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    page_log_algebra.DeletePageLogBefore(before:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_before(before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(page_log_algebra.DeletePageLogBeforeEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(name: page_log_algebra.EffectName) -> effect_trace.EffectName {
  effect_trace.LoggingEffectName(logging_algebra.PageLogName(name))
}
