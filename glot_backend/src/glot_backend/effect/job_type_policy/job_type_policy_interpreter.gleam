import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/job_type_policy/job_type_policy_algebra
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: job_type_policy_algebra.JobTypePolicyEffect(next_program),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    job_type_policy_algebra.GetJobTypePolicyByJobType(job_type:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.job_type_policy.get_job_type_policy_by_job_type(job_type)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.JobTypePolicyEffectName(
                job_type_policy_algebra.GetJobTypePolicyByJobTypeEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.JobTypePolicyEffectName(
              job_type_policy_algebra.GetJobTypePolicyByJobTypeEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
  }
}
