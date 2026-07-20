import glot_backend/logging/effect/algebra as logging_algebra
import glot_backend/logging/pageview/effect/algebra as pageview_log_algebra
import glot_backend/logging/pageview/ports/store.{type Store}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: pageview_log_algebra.PageviewLogEffect(next_program),
  store: Store,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    pageview_log_algebra.DeletePageviewLogBefore(before:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_before(before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(pageview_log_algebra.DeletePageviewLogBeforeEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(
  name: pageview_log_algebra.EffectName,
) -> effect_trace.EffectName {
  effect_trace.LoggingEffectName(logging_algebra.PageviewName(name))
}
