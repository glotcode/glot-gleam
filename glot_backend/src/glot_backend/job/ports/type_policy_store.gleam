import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error
import glot_core/job/job_model

pub type TypePolicyStore {
  TypePolicyStore(
    list_job_type_policies: fn() ->
      Result(List(job_model.JobTypePolicy), db_error.DbQueryError),
    get_job_type_policy_by_job_type: fn(job_model.JobType) ->
      Result(option.Option(job_model.JobTypePolicy), db_error.DbQueryError),
    upsert_job_type_policy: fn(job_model.JobTypePolicy, Timestamp) ->
      Result(Nil, db_error.DbCommandError),
  )
}
