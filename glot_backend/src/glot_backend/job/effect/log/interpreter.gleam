import glot_backend/job/effect/algebra as job_effect_algebra
import glot_backend/job/effect/log/algebra as job_log_algebra
import glot_backend/job/ports/log_store.{type LogStore}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: job_log_algebra.JobLogEffect(next_program),
  store: LogStore,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    job_log_algebra.ListJobLogs(request:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.list(request)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(job_log_algebra.ListJobLogsEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.database_query_error(query_error)),
          program_state.add_effect_measurement(
            state,
            trace_name(job_log_algebra.ListJobLogsEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    job_log_algebra.GetJobLog(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get(id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(job_log_algebra.GetJobLogEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.database_query_error(query_error)),
          program_state.add_effect_measurement(
            state,
            trace_name(job_log_algebra.GetJobLogEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    job_log_algebra.DeleteJobLogBefore(before:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_before(before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(job_log_algebra.DeleteJobLogBeforeEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(name: job_log_algebra.EffectName) -> effect_trace.EffectName {
  effect_trace.JobEffectName(job_effect_algebra.LogName(name))
}
