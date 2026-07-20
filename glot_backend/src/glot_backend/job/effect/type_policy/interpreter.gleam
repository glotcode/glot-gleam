import glot_backend/job/effect/algebra as job_effect_algebra
import glot_backend/job/effect/type_policy/algebra as job_type_policy_algebra
import glot_backend/job/ports/type_policy_store.{type TypePolicyStore}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: job_type_policy_algebra.JobTypePolicyEffect(next_program),
  store: TypePolicyStore,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    job_type_policy_algebra.ListJobTypePolicies(next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.list_job_type_policies()
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(job_type_policy_algebra.ListJobTypePoliciesEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(job_type_policy_algebra.ListJobTypePoliciesEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    job_type_policy_algebra.GetJobTypePolicyByJobType(job_type:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_job_type_policy_by_job_type(job_type)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(
                job_type_policy_algebra.GetJobTypePolicyByJobTypeEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(
              job_type_policy_algebra.GetJobTypePolicyByJobTypeEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    job_type_policy_algebra.UpsertJobTypePolicy(policy:, now:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.upsert_job_type_policy(policy, now)
      case result {
        Ok(_) ->
          continue(
            next(Nil),
            program_state.add_effect_measurement(
              state,
              trace_name(job_type_policy_algebra.UpsertJobTypePolicyEffectName),
              effect_trace.DatabaseWriteEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_command_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(job_type_policy_algebra.UpsertJobTypePolicyEffectName),
            effect_trace.DatabaseWriteEffect,
            started_at,
          ),
        )
      }
    }
  }
}

fn trace_name(
  name: job_type_policy_algebra.EffectName,
) -> effect_trace.EffectName {
  effect_trace.JobEffectName(job_effect_algebra.TypePolicyName(name))
}
