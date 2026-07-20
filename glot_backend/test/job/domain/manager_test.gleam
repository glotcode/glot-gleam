import gleam/dict
import gleam/option
import gleam/time/timestamp
import glot_backend/job/domain/manager as job_manager_domain
import glot_backend/system/request/context
import glot_core/job/job_model
import support/integration/fixture
import support/integration/profile/job as runner
import support/integration/store/common

pub fn recover_next_expired_job_reschedules_running_job_test() {
  let scheduled_job =
    job_model.delete_account_job(
      fixture.must_uuid("00000000-0000-0000-0000-000000000411"),
      option.Some(fixture.test_request_id()),
      fixture.test_timestamp(),
      fixture.test_timestamp(),
      fixture.test_account_id(),
      fixture.test_email_address(),
      fixture.test_job_type_policy(job_model.DeleteAccountJob),
    )
  let expired_job =
    job_model.start(
      scheduled_job,
      timestamp.from_unix_seconds_and_nanoseconds(1_699_999_000, 0),
    )
  let ctx =
    context.Context(
      ..fixture.test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [expired_job],
      account_delete_job_id: option.Some(expired_job.id),
    )

  let #(run_result, db) =
    runner.run_test_program(
      job_manager_domain.recover_next_expired_job(ctx),
      ctx,
      fixture.state,
    )

  let assert Ok(option.Some(recovered_job)) = run_result
  let assert Ok(stored_job) = dict.get(db.jobs, common.uuid_key(expired_job.id))

  assert recovered_job.status == job_model.Pending
  assert recovered_job.started_at == option.None
  assert recovered_job.lease_expires_at == option.None
  assert recovered_job.timed_out_at == option.Some(ctx.timestamp)
  assert recovered_job.last_error == option.Some("timeout_exceeded")
  assert stored_job == recovered_job
}
