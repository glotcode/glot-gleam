import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/effect/job/job
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: job.JobEffect(effect_model.Program(a)),
  handlers: handlers_types.Handlers,
  state: program_state.State,
  continue: fn(effect_model.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    job.GetNextJob(now:, pending_status:, running_status:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.get_next_job(now, pending_status, running_status)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_model.JobEffectName(job.GetNextJobEffectName),
              effect_model.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_model.JobEffectName(job.GetNextJobEffectName),
            effect_model.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    job.InsertJob(job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.insert_job(job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_model.JobEffectName(job.InsertJobEffectName),
          effect_model.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    job.MarkJobDone(id, completed_at, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.mark_job_done(id, completed_at)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_model.JobEffectName(job.MarkJobDoneEffectName),
          effect_model.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    job.RescheduleJob(id, run_at, last_error, updated_at, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.job.reschedule_job(id, run_at, last_error, updated_at)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_model.JobEffectName(job.RescheduleJobEffectName),
          effect_model.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
