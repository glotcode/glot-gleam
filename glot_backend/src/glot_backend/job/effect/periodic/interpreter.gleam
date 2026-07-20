import glot_backend/job/effect/algebra as job_effect_algebra
import glot_backend/job/effect/periodic/algebra as periodic_job_algebra
import glot_backend/job/ports/periodic_store.{type PeriodicStore}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: periodic_job_algebra.PeriodicJobEffect(next_program),
  store: PeriodicStore,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    periodic_job_algebra.ListPeriodicJobs(next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.list_periodic_jobs()
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(periodic_job_algebra.ListPeriodicJobsEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(periodic_job_algebra.ListPeriodicJobsEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    periodic_job_algebra.GetNextPeriodicJob(now:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_next_periodic_job(now)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(periodic_job_algebra.GetNextPeriodicJobEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(periodic_job_algebra.GetNextPeriodicJobEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    periodic_job_algebra.GetPeriodicJobById(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_periodic_job_by_id(id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(periodic_job_algebra.GetPeriodicJobByIdEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(periodic_job_algebra.GetPeriodicJobByIdEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    periodic_job_algebra.CreatePeriodicJob(periodic_job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.create_periodic_job(periodic_job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(periodic_job_algebra.CreatePeriodicJobEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    periodic_job_algebra.UpdatePeriodicJob(periodic_job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.update_periodic_job(periodic_job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(periodic_job_algebra.UpdatePeriodicJobEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(
  name: periodic_job_algebra.EffectName,
) -> effect_trace.EffectName {
  effect_trace.JobEffectName(job_effect_algebra.PeriodicName(name))
}
