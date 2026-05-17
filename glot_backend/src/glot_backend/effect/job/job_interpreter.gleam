import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/job/job_algebra
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: job_algebra.JobEffect(next_program),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    job_algebra.ListJobs(filter:, pagination:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.list_jobs(filter, pagination)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.JobEffectName(job_algebra.ListJobsEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.JobEffectName(job_algebra.ListJobsEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    job_algebra.SummarizeJobs(filter:, now:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.summarize_jobs(filter, now)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.JobEffectName(job_algebra.SummarizeJobsEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.JobEffectName(job_algebra.SummarizeJobsEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    job_algebra.GetNextJob(now:, pending_status:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.get_next_job(now, pending_status)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.JobEffectName(job_algebra.GetNextJobEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.JobEffectName(job_algebra.GetNextJobEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    job_algebra.GetExpiredRunningJob(now:, running_status:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.get_expired_running_job(now, running_status)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.JobEffectName(
                job_algebra.GetExpiredRunningJobEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.JobEffectName(
              job_algebra.GetExpiredRunningJobEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    job_algebra.GetJobById(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.get_job_by_id(id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.JobEffectName(job_algebra.GetJobByIdEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.JobEffectName(job_algebra.GetJobByIdEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    job_algebra.CreateJob(job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.create_job(job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.JobEffectName(job_algebra.CreateJobEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    job_algebra.UpdateJob(job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.update_job(job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.JobEffectName(job_algebra.UpdateJobEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    job_algebra.DeleteJob(id, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.delete_job(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.JobEffectName(job_algebra.DeleteJobEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    job_algebra.DeleteBefore(before:, statuses:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.delete_before(before, statuses)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.JobEffectName(job_algebra.DeleteBeforeEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
