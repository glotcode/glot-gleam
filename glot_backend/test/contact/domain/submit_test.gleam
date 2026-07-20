import gleam/dict
import glot_backend/contact/domain/submit as submit_contact_domain
import glot_backend/system/request/hydrated_context as request_context
import glot_core/contact_dto
import support/integration/fixture
import support/integration/model
import support/integration/profile/contact as runner
import support/integration/store/common

pub fn anonymous_contact_queues_email_and_audit_action_test() {
  let user_action_id = fixture.must_uuid("00000000-0000-0000-0000-000000000541")
  let job_id = fixture.must_uuid("00000000-0000-0000-0000-000000000542")
  let ctx = fixture.anonymous_test_context()
  let db =
    model.TestState(..fixture.empty_test_state(), next_uuids: [
      user_action_id,
      job_id,
    ])
  let request =
    contact_dto.ContactRequest(
      email: "visitor@example.com",
      topic: "privacy",
      message: "Please tell me what data you hold about me.",
      website: "",
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      submit_contact_domain.submit_contact(
        request_context.new(ctx, db.dynamic_config),
        request,
      ),
      ctx,
      db,
    )

  assert run_result == Ok(Nil)
  assert dict.has_key(updated_db.jobs, common.uuid_key(job_id))
  assert updated_db.user_action_count == 1
}

pub fn contact_honeypot_is_acknowledged_without_email_test() {
  let user_action_id = fixture.must_uuid("00000000-0000-0000-0000-000000000543")
  let ctx = fixture.anonymous_test_context()
  let db =
    model.TestState(..fixture.empty_test_state(), next_uuids: [user_action_id])
  let request =
    contact_dto.ContactRequest(
      email: "bot@example.com",
      topic: "general",
      message: "Automated message",
      website: "https://spam.example",
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      submit_contact_domain.submit_contact(
        request_context.new(ctx, db.dynamic_config),
        request,
      ),
      ctx,
      db,
    )

  assert run_result == Ok(Nil)
  assert dict.is_empty(updated_db.jobs)
  assert updated_db.user_action_count == 1
}
