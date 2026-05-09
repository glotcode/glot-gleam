import glot_backend/effect/admin_log/admin_log_algebra
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: admin_log_algebra.AdminLogEffect(next_program),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    admin_log_algebra.ListApiLogs(request:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.admin_log.list_api_logs(request)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AdminLogEffectName(
                admin_log_algebra.ListApiLogsEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.QueryError(query_error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AdminLogEffectName(
              admin_log_algebra.ListApiLogsEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    admin_log_algebra.GetApiLog(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.admin_log.get_api_log(id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AdminLogEffectName(
                admin_log_algebra.GetApiLogEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.QueryError(query_error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AdminLogEffectName(
              admin_log_algebra.GetApiLogEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    admin_log_algebra.ListJobLogs(request:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.admin_log.list_job_logs(request)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AdminLogEffectName(
                admin_log_algebra.ListJobLogsEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.QueryError(query_error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AdminLogEffectName(
              admin_log_algebra.ListJobLogsEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    admin_log_algebra.GetJobLog(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.admin_log.get_job_log(id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AdminLogEffectName(
                admin_log_algebra.GetJobLogEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.QueryError(query_error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AdminLogEffectName(
              admin_log_algebra.GetJobLogEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
  }
}
