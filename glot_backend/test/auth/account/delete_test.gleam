import gleam/dict
import gleam/list
import gleam/option
import glot_backend/auth/domain/account/cancel_delete as cancel_delete_account_domain
import glot_backend/auth/domain/account/schedule_delete as schedule_delete_account_domain
import glot_backend/job/domain/manager as job_manager_domain
import glot_backend/system/effect/error
import glot_backend/system/effect/error/resource_error
import glot_backend/system/request/hydrated_context as request_context
import glot_core/job/job_model
import support/integration/fixture
import support/integration/model
import support/integration/profile/auth as runner
import support/integration/store/common

pub fn schedule_delete_account_sets_delete_job_id_test() {
  let delete_job_id = fixture.must_uuid("00000000-0000-0000-0000-000000000102")
  let base_fixture =
    fixture.integration_fixture(
      next_uuids: [
        fixture.must_uuid("00000000-0000-0000-0000-000000000101"),
        delete_job_id,
      ],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let delete_account_policy =
    job_model.JobTypePolicy(
      ..fixture.test_job_type_policy(job_model.DeleteAccountJob),
      max_attempts: 9,
      timeout_seconds: 777,
    )
  let fixture =
    model.TestFixture(
      ..base_fixture,
      state: model.TestState(
        ..base_fixture.state,
        job_type_policies: dict.insert(
          base_fixture.state.job_type_policies,
          job_model.job_type_to_string(job_model.DeleteAccountJob),
          delete_account_policy,
        ),
      ),
    )

  let #(run_result, db) =
    runner.run_test_program(
      schedule_delete_account_domain.schedule_delete_account(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Ok(Nil)

  let assert Ok(updated_account) =
    dict.get(db.accounts, common.uuid_key(fixture.account.id))
  let assert option.Some(stored_job_id) = updated_account.delete_job_id
  let assert Ok(created_job) = dict.get(db.jobs, common.uuid_key(stored_job_id))

  assert stored_job_id == delete_job_id
  assert created_job.job_type == job_model.DeleteAccountJob
  assert created_job.max_attempts == 9
  assert created_job.timeout_seconds == 777
}

pub fn schedule_delete_account_rejects_existing_pending_delete_job_test() {
  let delete_job =
    job_model.delete_account_job(
      fixture.must_uuid("00000000-0000-0000-0000-000000000202"),
      option.Some(fixture.test_request_id()),
      fixture.test_timestamp(),
      fixture.test_timestamp(),
      fixture.test_account_id(),
      fixture.test_email_address(),
      fixture.test_job_type_policy(job_model.DeleteAccountJob),
    )
  let fixture =
    fixture.integration_fixture(
      next_uuids: [
        fixture.must_uuid("00000000-0000-0000-0000-000000000201"),
        fixture.must_uuid("00000000-0000-0000-0000-000000000299"),
      ],
      jobs: [delete_job],
      account_delete_job_id: option.Some(delete_job.id),
    )

  let #(run_result, db) =
    runner.run_test_program(
      schedule_delete_account_domain.schedule_delete_account(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result
    == Error(error.resource(resource_error.AccountDeleteAlreadyScheduled))

  let assert Ok(updated_account) =
    dict.get(db.accounts, common.uuid_key(fixture.account.id))

  assert updated_account.delete_job_id == option.Some(delete_job.id)
  assert list.length(dict.to_list(db.jobs)) == 1
  assert dict.get(db.jobs, common.uuid_key(delete_job.id)) == Ok(delete_job)
}

pub fn cancel_delete_account_clears_delete_job_id_and_removes_job_test() {
  let delete_job =
    job_model.delete_account_job(
      fixture.must_uuid("00000000-0000-0000-0000-000000000302"),
      option.Some(fixture.test_request_id()),
      fixture.test_timestamp(),
      fixture.test_timestamp(),
      fixture.test_account_id(),
      fixture.test_email_address(),
      fixture.test_job_type_policy(job_model.DeleteAccountJob),
    )
  let fixture =
    fixture.integration_fixture(
      next_uuids: [fixture.must_uuid("00000000-0000-0000-0000-000000000301")],
      jobs: [delete_job],
      account_delete_job_id: option.Some(delete_job.id),
    )

  let #(run_result, db) =
    runner.run_test_program(
      cancel_delete_account_domain.cancel_delete_account(request_context.new(
        fixture.ctx,
        fixture.state.dynamic_config,
      )),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Ok(Nil)

  let assert Ok(updated_account) =
    dict.get(db.accounts, common.uuid_key(fixture.account.id))

  assert updated_account.delete_job_id == option.None
  assert dict.get(db.jobs, common.uuid_key(delete_job.id)) == Error(Nil)
}

pub fn delete_account_job_execution_removes_data_in_order_test() {
  let send_email_policy =
    job_model.JobTypePolicy(
      ..fixture.test_job_type_policy(job_model.SendEmailJob),
      max_attempts: 3,
      timeout_seconds: 900,
    )
  let scheduled_job =
    job_model.delete_account_job(
      fixture.must_uuid("00000000-0000-0000-0000-000000000402"),
      option.Some(fixture.test_request_id()),
      fixture.test_timestamp(),
      fixture.test_timestamp(),
      fixture.test_account_id(),
      fixture.test_email_address(),
      fixture.test_job_type_policy(job_model.DeleteAccountJob),
    )
  let running_job = job_model.start(scheduled_job, fixture.test_timestamp())
  let base_fixture =
    fixture.integration_fixture(
      next_uuids: [fixture.must_uuid("00000000-0000-0000-0000-000000000403")],
      jobs: [running_job],
      account_delete_job_id: option.Some(running_job.id),
    )
  let fixture =
    model.TestFixture(
      ..base_fixture,
      state: model.TestState(
        ..base_fixture.state,
        job_type_policies: dict.insert(
          base_fixture.state.job_type_policies,
          job_model.job_type_to_string(job_model.SendEmailJob),
          send_email_policy,
        ),
      ),
    )

  let #(run_result, db) =
    runner.run_test_program(
      job_manager_domain.process_job(fixture.ctx, running_job),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Ok(Nil)

  let assert Ok(completed_job) =
    dict.get(db.jobs, common.uuid_key(running_job.id))
  let assert Ok(created_email_job) =
    dict.get(
      db.jobs,
      common.uuid_key(fixture.must_uuid("00000000-0000-0000-0000-000000000403")),
    )

  assert dict.to_list(db.accounts) == []
  assert dict.to_list(db.users) == []
  assert dict.to_list(db.sessions) == []
  assert dict.to_list(db.snippets) == []
  assert completed_job.status == job_model.Done
  assert completed_job.completed_at == option.Some(fixture.test_system_time())
  assert created_email_job.job_type == job_model.SendEmailJob
  assert created_email_job.status == job_model.Pending
  assert created_email_job.max_attempts == 3
  assert created_email_job.timeout_seconds == 900
  assert list.reverse(db.deletion_steps)
    == [
      "delete_sessions_by_account_id",
      "delete_snippets_by_account_id",
      "delete_users_by_account_id",
      "delete_account",
    ]
}
