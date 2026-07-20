import glot_backend/logging/effect/algebra as logging_algebra
import glot_backend/logging/run_log/effect/algebra as run_log_algebra
import glot_backend/logging/run_log/ports/store.{type Store}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: run_log_algebra.RunLogEffect(next_program),
  store: Store,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    run_log_algebra.CreateRunLog(run_log:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.create(run_log)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(run_log_algebra.CreateRunLogEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    run_log_algebra.ListRunLogs(request:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.list(request)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(run_log_algebra.ListRunLogsEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.database_query_error(query_error)),
          program_state.add_effect_measurement(
            state,
            trace_name(run_log_algebra.ListRunLogsEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    run_log_algebra.GetRunLog(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get(id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(run_log_algebra.GetRunLogEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.database_query_error(query_error)),
          program_state.add_effect_measurement(
            state,
            trace_name(run_log_algebra.GetRunLogEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    run_log_algebra.DeleteRunLogBefore(before:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_before(before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(run_log_algebra.DeleteRunLogBeforeEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(name: run_log_algebra.EffectName) -> effect_trace.EffectName {
  effect_trace.LoggingEffectName(logging_algebra.RunLogName(name))
}
