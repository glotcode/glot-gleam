import glot_backend/job/effect/algebra as job_effect_algebra
import glot_backend/job/effect/job/algebra as job_algebra
import glot_backend/job/ports/job_store.{type JobStore}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: job_algebra.JobEffect(next_program),
  store: JobStore,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    job_algebra.ListJobs(filter:, pagination:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.list_jobs(filter, pagination)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(job_algebra.ListJobsEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(job_algebra.ListJobsEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    job_algebra.SummarizeJobs(filter:, now:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.summarize_jobs(filter, now)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(job_algebra.SummarizeJobsEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(job_algebra.SummarizeJobsEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    job_algebra.GetNextJob(now:, pending_status:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_next_job(now, pending_status)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(job_algebra.GetNextJobEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(job_algebra.GetNextJobEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    job_algebra.GetExpiredRunningJob(now:, running_status:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_expired_running_job(now, running_status)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(job_algebra.GetExpiredRunningJobEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(job_algebra.GetExpiredRunningJobEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    job_algebra.GetJobById(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_job_by_id(id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(job_algebra.GetJobByIdEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(job_algebra.GetJobByIdEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    job_algebra.CreateJob(job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.create_job(job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(job_algebra.CreateJobEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    job_algebra.UpdateJob(job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.update_job(job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(job_algebra.UpdateJobEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    job_algebra.DeleteJob(id, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_job(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(job_algebra.DeleteJobEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    job_algebra.DeleteBefore(before:, statuses:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_before(before, statuses)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(job_algebra.DeleteBeforeEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(name: job_algebra.EffectName) -> effect_trace.EffectName {
  effect_trace.JobEffectName(job_effect_algebra.JobName(name))
}
