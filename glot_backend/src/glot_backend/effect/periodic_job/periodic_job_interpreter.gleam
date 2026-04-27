import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/periodic_job/periodic_job_algebra
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: periodic_job_algebra.PeriodicJobEffect(next_program),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    periodic_job_algebra.GetNextPeriodicJob(now:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.periodic_job.get_next_periodic_job(now)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.PeriodicJobEffectName(
                periodic_job_algebra.GetNextPeriodicJobEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.PeriodicJobEffectName(
              periodic_job_algebra.GetNextPeriodicJobEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    periodic_job_algebra.CreatePeriodicJob(periodic_job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.periodic_job.create_periodic_job(periodic_job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.PeriodicJobEffectName(
            periodic_job_algebra.CreatePeriodicJobEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    periodic_job_algebra.UpdatePeriodicJob(periodic_job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.periodic_job.update_periodic_job(periodic_job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.PeriodicJobEffectName(
            periodic_job_algebra.UpdatePeriodicJobEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
