import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/order
import gleam/regexp
import gleam/time/timestamp
import gleeunit
import glot_backend/context
import glot_backend/domain/account/cancel_delete_account_domain
import glot_backend/domain/account/schedule_delete_account_domain
import glot_backend/domain/auth/login_domain
import glot_backend/domain/auth/send_login_token_domain
import glot_backend/domain/cleanup/clean_jobs_domain
import glot_backend/domain/cleanup/clean_login_tokens_domain
import glot_backend/domain/cleanup/clean_user_actions_domain
import glot_backend/domain/job/job_manager_domain
import glot_backend/domain/job/periodic_job_manager_domain
import glot_backend/domain/run_code/get_language_version_domain
import glot_backend/domain/snippet/create_snippet_domain
import glot_backend/domain/shared/session_domain
import glot_backend/domain/snippet/update_snippet_domain
import glot_backend/effect/api_log/api_log_algebra
import glot_backend/effect/analytics/analytics_algebra
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/email/email_algebra
import glot_backend/effect/error
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/job/job_algebra
import glot_backend/effect/job_log/job_log_algebra
import glot_backend/effect/page_log/page_log_algebra
import glot_backend/effect/pageview_log/pageview_log_algebra
import glot_backend/effect/periodic_job/periodic_job_algebra
import glot_backend/effect/program_types
import glot_backend/effect/run_log/run_log_algebra
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/effect/user_action/user_action_algebra
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/auth/login_dto
import glot_core/auth/login_token_dto
import glot_core/auth/login_token_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/job/job_model
import glot_core/language
import glot_core/run
import glot_core/helpers/timestamp_helpers
import glot_core/periodic_job/periodic_job_model
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_core/snippet/snippet_spam
import glot_core/user_action
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn get_session_without_token_returns_none_test() {
  let ctx = test_context()

  let #(run_result, _) =
    run_test_program(session_domain.get_session(ctx), ctx, empty_test_db())

  assert run_result == Ok(option.None)
}

pub fn get_session_with_missing_db_session_returns_none_test() {
  let ctx =
    context.Context(
      ..test_context(),
      client_info: context.ClientInfo(
        session_token: option.Some("missing-session-token"),
        ip: option.None,
        user_agent: option.None,
        referrer: option.None,
      ),
    )

  let #(run_result, _) =
    run_test_program(session_domain.get_session(ctx), ctx, empty_test_db())

  assert run_result == Ok(option.None)
}

pub fn require_session_without_token_returns_missing_token_error_test() {
  let ctx = test_context()

  let #(run_result, _) =
    run_test_program(session_domain.require_session(ctx), ctx, empty_test_db())

  assert run_result == Error(error.SessionError(error.MissingSessionTokenError))
}

pub fn require_session_with_missing_db_session_returns_not_found_error_test() {
  let ctx =
    context.Context(
      ..test_context(),
      client_info: context.ClientInfo(
        session_token: option.Some("missing-session-token"),
        ip: option.None,
        user_agent: option.None,
        referrer: option.None,
      ),
    )

  let #(run_result, _) =
    run_test_program(session_domain.require_session(ctx), ctx, empty_test_db())

  assert run_result == Error(error.SessionError(error.SessionNotFoundError))
}

pub fn get_language_version_without_session_reaches_docker_run_test() {
  let ctx = test_context()
  let request = run.GetLanguageVersionRequest(language: language.Python)

  let #(run_result, db) =
    run_test_program(
      get_language_version_domain.get_language_version(ctx, request),
      ctx,
      empty_test_db(),
    )

  assert run_result
    == Error(error.RunError(error.InternalRunRequestError("unused in test")))
  assert db.write_steps == []
}

pub fn login_creates_account_user_and_session_in_foreign_key_order_test() {
  let login_token =
    login_token_model.LoginToken(
      id: must_uuid("00000000-0000-0000-0000-000000000501"),
      email: test_email_address(),
      token: "login-token",
      created_at: test_timestamp(),
      used_at: option.None,
    )
  let db =
    TestDb(
      ..empty_test_db(),
      login_tokens: dict.from_list([#(uuid_key(login_token.id), login_token)]),
      next_uuids: [
        must_uuid("00000000-0000-0000-0000-000000000502"),
        must_uuid("00000000-0000-0000-0000-000000000503"),
        must_uuid("00000000-0000-0000-0000-000000000504"),
      ],
    )
  let ctx =
    context.Context(
      ..test_context(),
      request_id: test_request_id(),
      timestamp: test_timestamp(),
      client_info: context.ClientInfo(
        session_token: option.None,
        ip: option.Some("127.0.0.1"),
        user_agent: option.Some("gleeunit"),
        referrer: option.None,
      ),
    )
  let request =
    login_dto.LoginRequest(email: test_email_address(), token: "login-token")

  let #(run_result, updated_db) =
    run_test_program(login_domain.login(ctx, request), ctx, db)

  assert run_result == Ok("random")
  assert list.reverse(updated_db.write_steps)
    == [
      "update_login_token",
      "create_account",
      "create_user",
      "create_session",
      "create_user_action",
    ]
}

pub fn send_login_token_for_suspended_user_returns_account_state_error_test() {
  let fixture =
    suspended_integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request = login_token_dto.LoginTokenRequest(email: fixture.user.email)

  let #(run_result, db) =
    run_test_program(
      send_login_token_domain.send_login_token(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Error(
      error.AccountStateError(error.ForbiddenAccountState(
        action: api_action.SendLoginTokenAction,
        account_state: account_model.Suspended,
      )),
    )
  assert db.write_steps == []
}

pub fn login_for_suspended_user_returns_account_state_error_test() {
  let login_token =
    login_token_model.LoginToken(
      id: must_uuid("00000000-0000-0000-0000-000000000601"),
      email: test_email_address(),
      token: "login-token",
      created_at: test_timestamp(),
      used_at: option.None,
    )
  let fixture =
    suspended_integration_fixture(
      next_uuids: [
        must_uuid("00000000-0000-0000-0000-000000000602"),
        must_uuid("00000000-0000-0000-0000-000000000603"),
        must_uuid("00000000-0000-0000-0000-000000000604"),
      ],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let db =
    TestDb(
      ..fixture.db,
      login_tokens: dict.from_list([#(uuid_key(login_token.id), login_token)]),
    )
  let ctx =
    context.Context(
      ..fixture.ctx,
      client_info: context.ClientInfo(
        session_token: option.None,
        ip: option.Some("127.0.0.1"),
        user_agent: option.Some("gleeunit"),
        referrer: option.None,
      ),
    )
  let request =
    login_dto.LoginRequest(email: test_email_address(), token: "login-token")

  let #(run_result, updated_db) =
    run_test_program(login_domain.login(ctx, request), ctx, db)

  assert run_result
    == Error(
      error.AccountStateError(error.ForbiddenAccountState(
        action: api_action.LoginAction,
        account_state: account_model.Suspended,
      )),
    )
  assert updated_db.write_steps == []
}

pub fn snippet_spam_filter_allows_normal_code_test() {
  assert snippet_spam.ensure_clean(
      snippet_dto.SnippetData(
        title: "Hello world",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [
          snippet_model.File(name: "main.py", content: "print(\"hello\")"),
        ],
      ),
    )
    == Ok(Nil)
}

pub fn snippet_spam_filter_blocks_obvious_spam_test() {
  let result =
    snippet_spam.ensure_clean(
      snippet_dto.SnippetData(
        title: "Earn money fast",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [
          snippet_model.File(
            name: "promo.txt",
            content: "Contact me on Telegram https://t.me/spam_now click here",
          ),
        ],
      ),
    )

  let assert Error(message) = result
  assert message != ""
}

pub fn create_snippet_rejects_empty_files_test() {
  let fixture =
    integration_fixture(
      next_uuids: [must_uuid("00000000-0000-0000-0000-000000000701")],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request =
    snippet_dto.CreateSnippetRequest(
      data: snippet_dto.SnippetData(
        title: "Snippet",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [],
      ),
    )

  let #(run_result, db) =
    run_test_program(
      create_snippet_domain.create_snippet(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Error(error.ValidationError("files must contain at least one file"))
  assert db.write_steps == []
}

pub fn create_snippet_rejects_too_long_title_test() {
  let fixture =
    integration_fixture(
      next_uuids: [must_uuid("00000000-0000-0000-0000-000000000702")],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request =
    snippet_dto.CreateSnippetRequest(
      data: snippet_dto.SnippetData(
        title: repeat_string("a", 201),
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [snippet_model.File(name: "main.py", content: "print(1)")],
      ),
    )

  let #(run_result, db) =
    run_test_program(
      create_snippet_domain.create_snippet(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Error(error.ValidationError("title must be at most 200 characters"))
  assert db.write_steps == []
}

pub fn update_snippet_rejects_too_long_file_content_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request =
    snippet_dto.UpdateSnippetRequest(
      slug: fixture.snippet.slug,
      data: snippet_dto.SnippetData(
        title: "Snippet",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [
          snippet_model.File(
            name: "main.py",
            content: repeat_string("a", 100_001),
          ),
        ],
      ),
    )

  let #(run_result, db) =
    run_test_program(
      update_snippet_domain.update_snippet(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Error(
      error.ValidationError(
        "files[0].content must be at most 100000 characters",
      ),
    )
  assert db.write_steps == []
}

pub fn schedule_delete_account_sets_delete_job_id_test() {
  let delete_job_id = must_uuid("00000000-0000-0000-0000-000000000102")
  let fixture =
    integration_fixture(
      next_uuids: [
        must_uuid("00000000-0000-0000-0000-000000000101"),
        delete_job_id,
      ],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, db) =
    run_test_program(
      schedule_delete_account_domain.schedule_delete_account(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Ok(Nil)

  let assert Ok(updated_account) =
    dict.get(db.accounts, uuid_key(fixture.account.id))
  let assert option.Some(stored_job_id) = updated_account.delete_job_id
  let assert Ok(created_job) = dict.get(db.jobs, uuid_key(stored_job_id))

  assert stored_job_id == delete_job_id
  assert created_job.job_type == job_model.DeleteAccountJob
}

pub fn schedule_delete_account_rejects_existing_pending_delete_job_test() {
  let delete_job =
    job_model.delete_account_job(
      must_uuid("00000000-0000-0000-0000-000000000202"),
      option.Some(test_request_id()),
      test_timestamp(),
      test_timestamp(),
      test_account_id(),
      test_email_address(),
    )
  let fixture =
    integration_fixture(
      next_uuids: [
        must_uuid("00000000-0000-0000-0000-000000000201"),
        must_uuid("00000000-0000-0000-0000-000000000299"),
      ],
      jobs: [delete_job],
      account_delete_job_id: option.Some(delete_job.id),
    )

  let #(run_result, db) =
    run_test_program(
      schedule_delete_account_domain.schedule_delete_account(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Error(error.ConflictError(
      "account_delete_already_scheduled",
      "Account deletion already scheduled",
    ))

  let assert Ok(updated_account) =
    dict.get(db.accounts, uuid_key(fixture.account.id))

  assert updated_account.delete_job_id == option.Some(delete_job.id)
  assert list.length(dict.to_list(db.jobs)) == 1
  assert dict.get(db.jobs, uuid_key(delete_job.id)) == Ok(delete_job)
}

pub fn cancel_delete_account_clears_delete_job_id_and_removes_job_test() {
  let delete_job =
    job_model.delete_account_job(
      must_uuid("00000000-0000-0000-0000-000000000302"),
      option.Some(test_request_id()),
      test_timestamp(),
      test_timestamp(),
      test_account_id(),
      test_email_address(),
    )
  let fixture =
    integration_fixture(
      next_uuids: [must_uuid("00000000-0000-0000-0000-000000000301")],
      jobs: [delete_job],
      account_delete_job_id: option.Some(delete_job.id),
    )

  let #(run_result, db) =
    run_test_program(
      cancel_delete_account_domain.cancel_delete_account(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Ok(Nil)

  let assert Ok(updated_account) =
    dict.get(db.accounts, uuid_key(fixture.account.id))

  assert updated_account.delete_job_id == option.None
  assert dict.get(db.jobs, uuid_key(delete_job.id)) == Error(Nil)
}

pub fn delete_account_job_execution_removes_data_in_order_test() {
  let scheduled_job =
    job_model.delete_account_job(
      must_uuid("00000000-0000-0000-0000-000000000402"),
      option.Some(test_request_id()),
      test_timestamp(),
      test_timestamp(),
      test_account_id(),
      test_email_address(),
    )
  let running_job = job_model.start(scheduled_job, test_timestamp())
  let fixture =
    integration_fixture(
      next_uuids: [must_uuid("00000000-0000-0000-0000-000000000403")],
      jobs: [running_job],
      account_delete_job_id: option.Some(running_job.id),
    )

  let #(run_result, db) =
    run_test_program(
      job_manager_domain.process_job(fixture.ctx, running_job),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Ok(Nil)

  let assert Ok(completed_job) = dict.get(db.jobs, uuid_key(running_job.id))
  let assert Ok(created_email_job) =
    dict.get(
      db.jobs,
      uuid_key(must_uuid("00000000-0000-0000-0000-000000000403")),
    )

  assert dict.to_list(db.accounts) == []
  assert dict.to_list(db.users) == []
  assert dict.to_list(db.sessions) == []
  assert dict.to_list(db.snippets) == []
  assert completed_job.status == job_model.Done
  assert completed_job.completed_at == option.Some(test_system_time())
  assert created_email_job.job_type == job_model.SendEmailJob
  assert created_email_job.status == job_model.Pending
  assert list.reverse(db.deletion_steps)
    == [
      "delete_sessions_by_account_id",
      "delete_snippets_by_account_id",
      "delete_users_by_account_id",
      "delete_account",
    ]
}

pub fn enqueue_next_due_periodic_job_creates_job_and_advances_schedule_test() {
  let periodic_job_id = must_uuid("00000000-0000-0000-0000-000000000801")
  let enqueued_job_id = must_uuid("00000000-0000-0000-0000-000000000802")
  let periodic_job =
    periodic_job_model.PeriodicJob(
      id: periodic_job_id,
      job_type: job_model.CleanApiLogJob,
      payload: option.None,
      interval_seconds: 86_400,
      enabled: True,
      next_run_at: test_timestamp(),
      last_enqueued_at: option.None,
      last_enqueue_error: option.None,
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let ctx = context.Context(..test_context(), timestamp: test_timestamp())
  let db =
    TestDb(
      ..empty_test_db(),
      periodic_jobs: dict.from_list([#(uuid_key(periodic_job_id), periodic_job)]),
      next_uuids: [enqueued_job_id],
    )

  let #(run_result, updated_db) =
    run_test_program(
      periodic_job_manager_domain.enqueue_next_due_periodic_job(ctx),
      ctx,
      db,
    )

  assert run_result == Ok(True)
  let assert Ok(enqueued_job) = dict.get(updated_db.jobs, uuid_key(enqueued_job_id))
  let assert Ok(updated_periodic_job) =
    dict.get(updated_db.periodic_jobs, uuid_key(periodic_job_id))

  assert enqueued_job.periodic_job_id == option.Some(periodic_job_id)
  assert enqueued_job.job_type == job_model.CleanApiLogJob
  assert enqueued_job.status == job_model.Pending
  assert updated_periodic_job.last_enqueued_at == option.Some(test_timestamp())
  assert updated_periodic_job.last_enqueue_error == option.None
  assert updated_periodic_job.next_run_at
    == timestamp.from_unix_seconds_and_nanoseconds(1_700_086_400, 0)
}

pub fn enqueue_next_due_periodic_job_returns_false_when_no_jobs_are_due_test() {
  let periodic_job =
    periodic_job_model.PeriodicJob(
      id: must_uuid("00000000-0000-0000-0000-000000000901"),
      job_type: job_model.CleanApiLogJob,
      payload: option.None,
      interval_seconds: 86_400,
      enabled: True,
      next_run_at: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_060, 0),
      last_enqueued_at: option.None,
      last_enqueue_error: option.None,
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let ctx = context.Context(..test_context(), timestamp: test_timestamp())
  let db =
    TestDb(
      ..empty_test_db(),
      periodic_jobs: dict.from_list([#(uuid_key(periodic_job.id), periodic_job)]),
    )

  let #(run_result, updated_db) =
    run_test_program(
      periodic_job_manager_domain.enqueue_next_due_periodic_job(ctx),
      ctx,
      db,
    )

  assert run_result == Ok(False)
  assert dict.to_list(updated_db.jobs) == []
  assert dict.get(updated_db.periodic_jobs, uuid_key(periodic_job.id))
    == Ok(periodic_job)
}

pub fn clean_jobs_deletes_only_done_jobs_before_cutoff_test() {
  let old_done_job =
    job_model.Job(
      id: must_uuid("00000000-0000-0000-0000-000000000a01"),
      request_id: option.None,
      periodic_job_id: option.None,
      job_type: job_model.CleanApiLogJob,
      payload: option.None,
      status: job_model.Done,
      attempts: 1,
      max_attempts: 5,
      timeout_seconds: 120,
      run_at: timestamp.from_unix_seconds_and_nanoseconds(1_650_000_000, 0),
      started_at: option.Some(timestamp.from_unix_seconds_and_nanoseconds(1_650_000_010, 0)),
      completed_at: option.Some(timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0)),
      last_error: option.None,
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_650_000_000, 0),
      updated_at: timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0),
    )
  let old_failed_job =
    job_model.Job(..old_done_job, id: must_uuid("00000000-0000-0000-0000-000000000a02"), status: job_model.Failed)
  let recent_done_job =
    job_model.Job(
      ..old_done_job,
      id: must_uuid("00000000-0000-0000-0000-000000000a03"),
      completed_at: option.Some(timestamp.from_unix_seconds_and_nanoseconds(1_699_900_000, 0)),
      updated_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_900_000, 0),
    )
  let ctx =
    context.Context(
      ..test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let db =
    TestDb(
      ..empty_test_db(),
      jobs: dict.from_list([
        #(uuid_key(old_done_job.id), old_done_job),
        #(uuid_key(old_failed_job.id), old_failed_job),
        #(uuid_key(recent_done_job.id), recent_done_job),
      ]),
    )

  let #(run_result, updated_db) =
    run_test_program(clean_jobs_domain.clean_jobs(ctx), ctx, db)

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.jobs, uuid_key(old_done_job.id)) == Error(Nil)
  assert dict.get(updated_db.jobs, uuid_key(old_failed_job.id)) == Ok(old_failed_job)
  assert dict.get(updated_db.jobs, uuid_key(recent_done_job.id)) == Ok(recent_done_job)
}

pub fn clean_user_actions_deletes_only_old_rows_test() {
  let old_action =
    user_action.UserAction(
      id: must_uuid("00000000-0000-0000-0000-000000000b01"),
      request_id: test_request_id(),
      action: api_action.LoginAction,
      ip: option.Some("127.0.0.1"),
      user_id: option.None,
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0),
    )
  let recent_action =
    user_action.UserAction(
      ..old_action,
      id: must_uuid("00000000-0000-0000-0000-000000000b02"),
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_900_000, 0),
    )
  let ctx =
    context.Context(
      ..test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let db =
    TestDb(
      ..empty_test_db(),
      user_actions: dict.from_list([
        #(uuid_key(old_action.id), old_action),
        #(uuid_key(recent_action.id), recent_action),
      ]),
    )

  let #(run_result, updated_db) =
    run_test_program(clean_user_actions_domain.clean_user_actions(ctx), ctx, db)

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.user_actions, uuid_key(old_action.id)) == Error(Nil)
  assert dict.get(updated_db.user_actions, uuid_key(recent_action.id))
    == Ok(recent_action)
}

pub fn clean_login_tokens_deletes_only_old_rows_test() {
  let old_login_token =
    login_token_model.LoginToken(
      id: must_uuid("00000000-0000-0000-0000-000000000c01"),
      email: test_email_address(),
      token: "old-login-token",
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0),
      used_at: option.None,
    )
  let recent_login_token =
    login_token_model.LoginToken(
      ..old_login_token,
      id: must_uuid("00000000-0000-0000-0000-000000000c02"),
      token: "recent-login-token",
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_900_000, 0),
    )
  let ctx =
    context.Context(
      ..test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let db =
    TestDb(
      ..empty_test_db(),
      login_tokens: dict.from_list([
        #(uuid_key(old_login_token.id), old_login_token),
        #(uuid_key(recent_login_token.id), recent_login_token),
      ]),
    )

  let #(run_result, updated_db) =
    run_test_program(
      clean_login_tokens_domain.clean_login_tokens(ctx),
      ctx,
      db,
    )

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.login_tokens, uuid_key(old_login_token.id))
    == Error(Nil)
  assert dict.get(updated_db.login_tokens, uuid_key(recent_login_token.id))
    == Ok(recent_login_token)
}

type TestFixture {
  TestFixture(
    ctx: context.Context,
    db: TestDb,
    account: account_model.Account,
    user: user_model.User,
    session: session_model.Session,
    snippet: snippet_model.Snippet,
  )
}

type TestDb {
  TestDb(
    accounts: Dict(String, account_model.Account),
    users: Dict(String, user_model.User),
    login_tokens: Dict(String, login_token_model.LoginToken),
    sessions: Dict(String, session_model.Session),
    session_ids_by_token: Dict(String, String),
    jobs: Dict(String, job_model.Job),
    periodic_jobs: Dict(String, periodic_job_model.PeriodicJob),
    snippets: Dict(String, snippet_model.Snippet),
    user_actions: Dict(String, user_action.UserAction),
    user_action_count: Int,
    write_steps: List(String),
    deletion_steps: List(String),
    next_uuids: List(uuid.Uuid),
    system_time: timestamp.Timestamp,
  )
}

fn integration_fixture(
  next_uuids next_uuids: List(uuid.Uuid),
  jobs jobs: List(job_model.Job),
  account_delete_job_id account_delete_job_id: option.Option(uuid.Uuid),
) -> TestFixture {
  let account =
    account_model.Account(
      id: test_account_id(),
      account_state: account_model.Active,
      account_state_reason: option.None,
      account_tier: account_model.FreeTier,
      delete_job_id: account_delete_job_id,
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let user =
    user_model.User(
      id: test_user_id(),
      account_id: account.id,
      email: email_address_model.EmailAddress("user@example.com"),
      username: "user",
      role: user_model.RegularUser,
      last_login_at: test_timestamp(),
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let session =
    session_model.Session(
      id: test_session_id(),
      user_id: user.id,
      token: "session-token",
      ip: option.Some("127.0.0.1"),
      user_agent: option.Some("gleeunit"),
      created_at: test_timestamp(),
    )
  let snippet =
    snippet_model.Snippet(
      id: test_snippet_id(),
      slug: "snippet-slug",
      user_id: user.id,
      title: "Snippet",
      language: language.Python,
      visibility: snippet_model.Public,
      stdin: "",
      run_instructions: option.None,
      files: [snippet_model.File(name: "main.py", content: "print(1)")],
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let db =
    TestDb(
      accounts: dict.from_list([#(uuid_key(account.id), account)]),
      users: dict.from_list([#(uuid_key(user.id), user)]),
      login_tokens: dict.new(),
      sessions: dict.from_list([#(uuid_key(session.id), session)]),
      session_ids_by_token: dict.from_list([
        #(session.token, uuid_key(session.id)),
      ]),
      jobs: dict.from_list(list.map(jobs, fn(job) { #(uuid_key(job.id), job) })),
      periodic_jobs: dict.new(),
      snippets: dict.from_list([#(uuid_key(snippet.id), snippet)]),
      user_actions: dict.new(),
      user_action_count: 0,
      write_steps: [],
      deletion_steps: [],
      next_uuids: next_uuids,
      system_time: test_system_time(),
    )
  let ctx =
    context.Context(
      ..test_context(),
      request_id: test_request_id(),
      timestamp: test_timestamp(),
      client_info: context.ClientInfo(
        session_token: option.Some(session.token),
        ip: option.Some("127.0.0.1"),
        user_agent: option.Some("gleeunit"),
        referrer: option.None,
      ),
    )

  TestFixture(
    ctx: ctx,
    db: db,
    account: account,
    user: user,
    session: session,
    snippet: snippet,
  )
}

fn suspended_integration_fixture(
  next_uuids next_uuids: List(uuid.Uuid),
  jobs jobs: List(job_model.Job),
  account_delete_job_id account_delete_job_id: option.Option(uuid.Uuid),
) -> TestFixture {
  let fixture =
    integration_fixture(
      next_uuids: next_uuids,
      jobs: jobs,
      account_delete_job_id: account_delete_job_id,
    )
  let suspended_account =
    account_model.Account(
      ..fixture.account,
      account_state: account_model.Suspended,
      account_state_reason: option.Some("suspended for test"),
    )
  let db =
    TestDb(
      ..fixture.db,
      accounts: dict.insert(
        fixture.db.accounts,
        uuid_key(suspended_account.id),
        suspended_account,
      ),
    )

  TestFixture(..fixture, db: db, account: suspended_account)
}

fn empty_test_db() -> TestDb {
  TestDb(
    accounts: dict.new(),
    users: dict.new(),
    login_tokens: dict.new(),
    sessions: dict.new(),
    session_ids_by_token: dict.new(),
    jobs: dict.new(),
    periodic_jobs: dict.new(),
    snippets: dict.new(),
    user_actions: dict.new(),
    user_action_count: 0,
    write_steps: [],
    deletion_steps: [],
    next_uuids: [],
    system_time: test_system_time(),
  )
}

fn repeat_string(value: String, count: Int) -> String {
  case count <= 0 {
    True -> ""
    False -> value <> repeat_string(value, count - 1)
  }
}

fn run_test_program(
  effect: program_types.Program(a),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    program_types.Pure(value) -> #(Ok(value), db)
    program_types.Fail(err) -> #(Error(err), db)
    program_types.Impure(next_effect) ->
      case next_effect {
        program_types.BasicEffect(basic_effect) ->
          run_test_basic_effect(basic_effect, ctx, db)
        program_types.EmailEffect(email_effect) ->
          run_test_email_effect(email_effect, ctx, db)
        program_types.DockerRunEffect(docker_run_effect) ->
          run_test_docker_run_effect(docker_run_effect, db)
        program_types.GetLanguageVersionEffect(get_language_version_effect) ->
          run_test_get_language_version_effect(get_language_version_effect, db)
        program_types.DbEffect(db_effect) ->
          run_test_db_effect(db_effect, ctx, db)
        program_types.TransactionEffect(program_types.Run(program: tx_program)) ->
          case run_test_tx_program(tx_program, ctx, db) {
            #(Ok(next_program), next_db) ->
              run_test_program(next_program, ctx, next_db)
            #(Error(err), next_db) -> #(Error(err), next_db)
          }
      }
  }
}

fn run_test_tx_program(
  effect: program_types.TransactionProgram(a),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    program_types.TxPure(value) -> #(Ok(value), db)
    program_types.TxFail(err) -> #(Error(err), db)
    program_types.TxImpure(db_effect) ->
      run_test_tx_db_effect(db_effect, ctx, db)
  }
}

fn run_test_basic_effect(
  effect: basic_algebra.BasicEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    basic_algebra.NewToken(_, _, next) ->
      run_test_program(next("random"), ctx, db)
    basic_algebra.SystemTime(next) ->
      run_test_program(next(db.system_time), ctx, db)
    basic_algebra.UuidV7(next) -> {
      let #(uuid_value, next_db) = pop_uuid(db)
      run_test_program(next(uuid_value), ctx, next_db)
    }
    basic_algebra.Log(_, _, next) -> run_test_program(next, ctx, db)
  }
}

fn run_test_email_effect(
  effect: email_algebra.EmailEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    email_algebra.SendEmail(_, next) ->
      run_test_program(
        next(Error(error.InternalSendEmailError("unused in test"))),
        ctx,
        db,
      )
  }
}

fn run_test_docker_run_effect(
  effect: docker_run_algebra.DockerRunEffect(program_types.Program(a)),
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    docker_run_algebra.RunCode(_, _, _) -> #(
      Error(error.RunError(error.InternalRunRequestError("unused in test"))),
      db,
    )
  }
}

fn run_test_get_language_version_effect(
  effect: get_language_version_algebra.GetLanguageVersionEffect(
    program_types.Program(a),
  ),
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    get_language_version_algebra.GetLanguageVersion(_, _, _) -> #(
      Error(error.RunError(error.InternalRunRequestError("unused in test"))),
      db,
    )
  }
}

fn run_test_db_effect(
  effect: program_types.DbEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    program_types.AnalyticsEffect(analytics_effect) ->
      run_test_analytics_effect(analytics_effect, ctx, db)
    program_types.ApiLogEffect(api_log_effect) ->
      run_test_api_log_effect(api_log_effect, ctx, db)
    program_types.AuthEffect(auth_effect) ->
      run_test_auth_effect(auth_effect, ctx, db)
    program_types.JobEffect(job_effect) ->
      run_test_job_effect(job_effect, ctx, db)
    program_types.JobLogEffect(job_log_effect) ->
      run_test_job_log_effect(job_log_effect, ctx, db)
    program_types.PageLogEffect(page_log_effect) ->
      run_test_page_log_effect(page_log_effect, ctx, db)
    program_types.PageviewLogEffect(pageview_log_effect) ->
      run_test_pageview_log_effect(pageview_log_effect, ctx, db)
    program_types.PeriodicJobEffect(periodic_job_effect) ->
      run_test_periodic_job_effect(periodic_job_effect, ctx, db)
    program_types.RunLogEffect(run_log_effect) ->
      run_test_run_log_effect(run_log_effect, ctx, db)
    program_types.SnippetEffect(snippet_effect) ->
      run_test_snippet_effect(snippet_effect, ctx, db)
    program_types.UserActionEffect(user_action_effect) ->
      run_test_user_action_effect(user_action_effect, ctx, db)
  }
}

fn run_test_tx_db_effect(
  effect: program_types.DbEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    program_types.AnalyticsEffect(analytics_effect) ->
      run_test_analytics_tx_effect(analytics_effect, ctx, db)
    program_types.ApiLogEffect(api_log_effect) ->
      run_test_api_log_tx_effect(api_log_effect, ctx, db)
    program_types.AuthEffect(auth_effect) ->
      run_test_auth_tx_effect(auth_effect, ctx, db)
    program_types.JobEffect(job_effect) ->
      run_test_job_tx_effect(job_effect, ctx, db)
    program_types.JobLogEffect(job_log_effect) ->
      run_test_job_log_tx_effect(job_log_effect, ctx, db)
    program_types.PageLogEffect(page_log_effect) ->
      run_test_page_log_tx_effect(page_log_effect, ctx, db)
    program_types.PageviewLogEffect(pageview_log_effect) ->
      run_test_pageview_log_tx_effect(pageview_log_effect, ctx, db)
    program_types.PeriodicJobEffect(periodic_job_effect) ->
      run_test_periodic_job_tx_effect(periodic_job_effect, ctx, db)
    program_types.RunLogEffect(run_log_effect) ->
      run_test_run_log_tx_effect(run_log_effect, ctx, db)
    program_types.SnippetEffect(snippet_effect) ->
      run_test_snippet_tx_effect(snippet_effect, ctx, db)
    program_types.UserActionEffect(user_action_effect) ->
      run_test_user_action_tx_effect(user_action_effect, ctx, db)
  }
}

fn run_test_api_log_effect(
  effect: api_log_algebra.ApiLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    api_log_algebra.DeleteApiLogBefore(before: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_analytics_effect(
  effect: analytics_algebra.AnalyticsEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    analytics_algebra.GetMaxCompletedMetricsDay(next:) ->
      run_test_program(next(Ok(option.None)), ctx, db)
    analytics_algebra.GetFirstMetricsSourceDay(before: _, next: next) ->
      run_test_program(next(Ok(option.None)), ctx, db)
    analytics_algebra.InsertMetricsPageviewDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsProductEventDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsRunDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsReliabilityPageDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsReliabilityApiDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsCompletedDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_analytics_tx_effect(
  effect: analytics_algebra.AnalyticsEffect(
    program_types.TransactionProgram(a),
  ),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    analytics_algebra.GetMaxCompletedMetricsDay(next:) ->
      run_test_tx_program(next(Ok(option.None)), ctx, db)
    analytics_algebra.GetFirstMetricsSourceDay(before: _, next: next) ->
      run_test_tx_program(next(Ok(option.None)), ctx, db)
    analytics_algebra.InsertMetricsPageviewDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsProductEventDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsRunDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsReliabilityPageDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsReliabilityApiDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsCompletedDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_api_log_tx_effect(
  effect: api_log_algebra.ApiLogEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    api_log_algebra.DeleteApiLogBefore(before: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_page_log_effect(
  effect: page_log_algebra.PageLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    page_log_algebra.DeletePageLogBefore(before: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_page_log_tx_effect(
  effect: page_log_algebra.PageLogEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    page_log_algebra.DeletePageLogBefore(before: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_pageview_log_effect(
  effect: pageview_log_algebra.PageviewLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    pageview_log_algebra.DeletePageviewLogBefore(before: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_pageview_log_tx_effect(
  effect: pageview_log_algebra.PageviewLogEffect(
    program_types.TransactionProgram(a),
  ),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    pageview_log_algebra.DeletePageviewLogBefore(before: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_periodic_job_effect(
  effect: periodic_job_algebra.PeriodicJobEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    periodic_job_algebra.GetNextPeriodicJob(now:, next:) ->
      run_test_program(next(find_next_periodic_job(db, now)), ctx, db)
    periodic_job_algebra.CreatePeriodicJob(periodic_job, next) ->
      run_test_program(next(Ok(Nil)), ctx, put_periodic_job(db, periodic_job))
    periodic_job_algebra.UpdatePeriodicJob(periodic_job, next) ->
      run_test_program(next(Ok(Nil)), ctx, put_periodic_job(db, periodic_job))
  }
}

fn run_test_periodic_job_tx_effect(
  effect: periodic_job_algebra.PeriodicJobEffect(
    program_types.TransactionProgram(a),
  ),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    periodic_job_algebra.GetNextPeriodicJob(now:, next:) ->
      run_test_tx_program(next(find_next_periodic_job(db, now)), ctx, db)
    periodic_job_algebra.CreatePeriodicJob(periodic_job, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, put_periodic_job(db, periodic_job))
    periodic_job_algebra.UpdatePeriodicJob(periodic_job, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, put_periodic_job(db, periodic_job))
  }
}

fn run_test_run_log_effect(
  effect: run_log_algebra.RunLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    run_log_algebra.CreateRunLog(run_log: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_run_log_tx_effect(
  effect: run_log_algebra.RunLogEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    run_log_algebra.CreateRunLog(run_log: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_auth_effect(
  effect: auth_algebra.AuthEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    auth_algebra.GetUserByEmail(email:, next:) ->
      run_test_program(next(find_user_by_email(db, email)), ctx, db)
    auth_algebra.ListLoginTokensByEmail(email:, limit:, next:) ->
      run_test_program(
        next(find_login_tokens_by_email(db, email, limit)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByToken(token:, next:) ->
      run_test_program(next(find_hydrated_session(db, token)), ctx, db)
    auth_algebra.CreateUser(user: user, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_user(db, user))
    auth_algebra.CreateAccount(account: account, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_account(db, account))
    auth_algebra.UpdateAccount(account: account, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_account(db, account))
    auth_algebra.UpdateUser(user: user, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_user(db, user))
    auth_algebra.DeleteSessionsByAccountId(account_id: account_id, next: next) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_sessions_by_account_id(db, account_id),
      )
    auth_algebra.DeleteUsersByAccountId(account_id: account_id, next: next) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_users_by_account_id(db, account_id),
      )
    auth_algebra.DeleteAccount(account_id: account_id, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, delete_account_by_id(db, account_id))
    auth_algebra.CreateSession(session: session, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_session(db, session))
    auth_algebra.DeleteSession(id: id, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, delete_session_by_id(db, id))
    auth_algebra.CreateLoginToken(login_token:, next:) -> {
      run_test_program(next(Ok(Nil)), ctx, upsert_login_token(db, login_token))
    }
    auth_algebra.UpdateLoginToken(login_token:, next:) ->
      run_test_program(next(Ok(Nil)), ctx, upsert_login_token(db, login_token))
    auth_algebra.DeleteLoginTokensBefore(before:, next:) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_login_tokens_before(db, before),
      )
  }
}

fn run_test_auth_tx_effect(
  effect: auth_algebra.AuthEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    auth_algebra.GetUserByEmail(email:, next:) ->
      run_test_tx_program(next(find_user_by_email(db, email)), ctx, db)
    auth_algebra.ListLoginTokensByEmail(email:, limit:, next:) ->
      run_test_tx_program(
        next(find_login_tokens_by_email(db, email, limit)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByToken(token:, next:) ->
      run_test_tx_program(next(find_hydrated_session(db, token)), ctx, db)
    auth_algebra.CreateUser(user: user, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_user(db, user))
    auth_algebra.CreateAccount(account: account, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_account(db, account))
    auth_algebra.UpdateAccount(account: account, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_account(db, account))
    auth_algebra.UpdateUser(user: user, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_user(db, user))
    auth_algebra.DeleteSessionsByAccountId(account_id: account_id, next: next) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_sessions_by_account_id(db, account_id),
      )
    auth_algebra.DeleteUsersByAccountId(account_id: account_id, next: next) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_users_by_account_id(db, account_id),
      )
    auth_algebra.DeleteAccount(account_id: account_id, next: next) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_account_by_id(db, account_id),
      )
    auth_algebra.CreateSession(session: session, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_session(db, session))
    auth_algebra.DeleteSession(id: id, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, delete_session_by_id(db, id))
    auth_algebra.CreateLoginToken(login_token:, next:) -> {
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        upsert_login_token(db, login_token),
      )
    }
    auth_algebra.UpdateLoginToken(login_token:, next:) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        upsert_login_token(db, login_token),
      )
    auth_algebra.DeleteLoginTokensBefore(before:, next:) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_login_tokens_before(db, before),
      )
  }
}

fn run_test_job_effect(
  effect: job_algebra.JobEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_algebra.GetNextJob(now:, pending_status:, next:) -> {
      let _ = now
      let _ = pending_status
      run_test_program(next(option.None), ctx, db)
    }
    job_algebra.GetJobById(id:, next:) ->
      run_test_program(next(find_job(db, id)), ctx, db)
    job_algebra.CreateJob(job, next) ->
      run_test_program(next(Ok(Nil)), ctx, put_job(db, job))
    job_algebra.UpdateJob(job, next) ->
      run_test_program(next(Ok(Nil)), ctx, put_job(db, job))
    job_algebra.DeleteJob(id, next) ->
      run_test_program(next(Ok(Nil)), ctx, delete_job_by_id(db, id))
    job_algebra.DeleteBefore(before:, statuses:, next:) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_jobs_before_by_statuses(db, before, statuses),
      )
  }
}

fn run_test_job_log_effect(
  effect: job_log_algebra.JobLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_log_algebra.DeleteJobLogBefore(before: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_job_tx_effect(
  effect: job_algebra.JobEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_algebra.GetNextJob(now:, pending_status:, next:) -> {
      let _ = now
      let _ = pending_status
      run_test_tx_program(next(option.None), ctx, db)
    }
    job_algebra.GetJobById(id:, next:) ->
      run_test_tx_program(next(find_job(db, id)), ctx, db)
    job_algebra.CreateJob(job, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, put_job(db, job))
    job_algebra.UpdateJob(job, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, put_job(db, job))
    job_algebra.DeleteJob(id, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, delete_job_by_id(db, id))
    job_algebra.DeleteBefore(before:, statuses:, next:) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_jobs_before_by_statuses(db, before, statuses),
      )
  }
}

fn run_test_job_log_tx_effect(
  effect: job_log_algebra.JobLogEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_log_algebra.DeleteJobLogBefore(before: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_snippet_effect(
  effect: snippet_algebra.SnippetEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    snippet_algebra.GetSnippetById(id, next) -> {
      let _ = id
      run_test_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.GetSnippetBySlug(slug, next) -> {
      let _ = slug
      run_test_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.ListSnippets(filter: _, pagination: _, next: next) ->
      run_test_program(next(Ok([])), ctx, db)
    snippet_algebra.DeleteSnippet(id, next) ->
      run_test_program(next(Ok(Nil)), ctx, delete_snippet_by_id(db, id))
    snippet_algebra.DeleteSnippetsByAccountId(
      account_id: account_id,
      next: next,
    ) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_snippets_by_account_id(db, account_id),
      )
    snippet_algebra.CreateSnippet(snippet, next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_snippet(db, snippet))
    snippet_algebra.UpdateSnippet(snippet, next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_snippet(db, snippet))
  }
}

fn run_test_snippet_tx_effect(
  effect: snippet_algebra.SnippetEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    snippet_algebra.GetSnippetById(id, next) -> {
      let _ = id
      run_test_tx_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.GetSnippetBySlug(slug, next) -> {
      let _ = slug
      run_test_tx_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.ListSnippets(filter: _, pagination: _, next: next) ->
      run_test_tx_program(next(Ok([])), ctx, db)
    snippet_algebra.DeleteSnippet(id, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, delete_snippet_by_id(db, id))
    snippet_algebra.DeleteSnippetsByAccountId(
      account_id: account_id,
      next: next,
    ) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_snippets_by_account_id(db, account_id),
      )
    snippet_algebra.CreateSnippet(snippet, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_snippet(db, snippet))
    snippet_algebra.UpdateSnippet(snippet, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_snippet(db, snippet))
  }
}

fn run_test_user_action_effect(
  effect: user_action_algebra.UserActionEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    user_action_algebra.CountUserActions(filter:, next:) -> {
      let _ = filter
      run_test_program(next([]), ctx, db)
    }
    user_action_algebra.CreateUserAction(user_action:, next:) -> {
      let _ = user_action
      run_test_program(next(Ok(Nil)), ctx, increment_user_action_count(db))
    }
    user_action_algebra.DeleteBefore(before:, next:) ->
      run_test_program(next(Ok(Nil)), ctx, delete_user_actions_before(db, before))
  }
}

fn run_test_user_action_tx_effect(
  effect: user_action_algebra.UserActionEffect(
    program_types.TransactionProgram(a),
  ),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    user_action_algebra.CountUserActions(filter:, next:) -> {
      let _ = filter
      run_test_tx_program(next([]), ctx, db)
    }
    user_action_algebra.CreateUserAction(user_action:, next:) -> {
      let _ = user_action
      run_test_tx_program(next(Ok(Nil)), ctx, increment_user_action_count(db))
    }
    user_action_algebra.DeleteBefore(before:, next:) ->
      run_test_tx_program(next(Ok(Nil)), ctx, delete_user_actions_before(db, before))
  }
}

fn pop_uuid(db: TestDb) -> #(uuid.Uuid, TestDb) {
  case db.next_uuids {
    [next, ..rest] -> #(next, TestDb(..db, next_uuids: rest))
    [] -> #(uuid.nil, db)
  }
}

fn find_job(db: TestDb, id: uuid.Uuid) -> option.Option(job_model.Job) {
  db.jobs
  |> dict.get(uuid_key(id))
  |> option.from_result()
}

fn find_next_periodic_job(
  db: TestDb,
  now: timestamp.Timestamp,
) -> option.Option(periodic_job_model.PeriodicJob) {
  db.periodic_jobs
  |> dict.to_list
  |> list.map(fn(entry) {
    let #(_, periodic_job) = entry
    periodic_job
  })
  |> list.filter(fn(periodic_job) {
    periodic_job.enabled
    && timestamp_helpers.to_microseconds(periodic_job.next_run_at)
      <= timestamp_helpers.to_microseconds(now)
  })
  |> list.sort(fn(a, b) {
    case
      timestamp_helpers.to_microseconds(a.next_run_at)
      < timestamp_helpers.to_microseconds(b.next_run_at)
    {
      True -> order.Lt
      False ->
        case
          timestamp_helpers.to_microseconds(a.next_run_at)
          > timestamp_helpers.to_microseconds(b.next_run_at)
        {
          True -> order.Gt
          False ->
            case
              timestamp_helpers.to_microseconds(a.created_at)
              < timestamp_helpers.to_microseconds(b.created_at)
            {
              True -> order.Lt
              False ->
                case
                  timestamp_helpers.to_microseconds(a.created_at)
                  > timestamp_helpers.to_microseconds(b.created_at)
                {
                  True -> order.Gt
                  False -> order.Eq
                }
            }
        }
    }
  })
  |> list.first
  |> option.from_result
}

fn find_user_by_email(
  db: TestDb,
  email: email_address_model.EmailAddress,
) -> option.Option(user_model.HydratedUser) {
  case
    db.users
    |> dict.to_list
    |> list.find(fn(entry) {
      let #(_, user) = entry
      user.email == email
    })
    |> option.from_result()
  {
    option.Some(entry) -> {
      let #(_, user) = entry
      db.accounts
      |> dict.get(uuid_key(user.account_id))
      |> option.from_result()
      |> option.map(fn(account) {
        user_model.HydratedUser(
          identity: user,
          account: account_model.HydratedAccount(
            identity: account,
            delete_scheduled_at: option.None,
          ),
        )
      })
    }
    option.None -> option.None
  }
}

fn find_session(db: TestDb, session_id: String) -> session_model.Session {
  let assert Ok(session) = dict.get(db.sessions, session_id)
  session
}

fn find_login_tokens_by_email(
  db: TestDb,
  email: email_address_model.EmailAddress,
  limit: Int,
) -> List(login_token_model.LoginToken) {
  let _ = limit

  db.login_tokens
  |> dict.to_list
  |> list.filter(fn(entry) {
    let #(_, login_token) = entry
    login_token.email == email
  })
  |> list.map(fn(entry) {
    let #(_, login_token) = entry
    login_token
  })
}

fn find_hydrated_session(
  db: TestDb,
  token: String,
) -> option.Option(session_model.HydratedSession) {
  case dict.get(db.session_ids_by_token, token) {
    Ok(session_id) ->
      case dict.get(db.sessions, session_id) {
        Ok(session) ->
          case dict.get(db.users, uuid_key(session.user_id)) {
            Ok(user) ->
              case dict.get(db.accounts, uuid_key(user.account_id)) {
                Ok(account) ->
                  option.Some(session_model.HydratedSession(
                    identity: session,
                    user: user_model.HydratedUser(
                      identity: user,
                      account: account_model.HydratedAccount(
                        identity: account,
                        delete_scheduled_at: option.None,
                      ),
                    ),
                  ))
                Error(_) -> option.None
              }
            Error(_) -> option.None
          }
        Error(_) -> option.None
      }
    Error(_) -> option.None
  }
}

fn session_belongs_to_account(
  db: TestDb,
  session: session_model.Session,
  account_id: uuid.Uuid,
) -> Bool {
  case dict.get(db.users, uuid_key(session.user_id)) {
    Ok(user) -> user.account_id == account_id
    Error(_) -> False
  }
}

fn insert_user(db: TestDb, user: user_model.User) -> TestDb {
  TestDb(
    ..db,
    users: dict.insert(db.users, uuid_key(user.id), user),
    write_steps: ["create_user", ..db.write_steps],
  )
}

fn insert_account(db: TestDb, account: account_model.Account) -> TestDb {
  TestDb(
    ..db,
    accounts: dict.insert(db.accounts, uuid_key(account.id), account),
    write_steps: ["create_account", ..db.write_steps],
  )
}

fn insert_session(db: TestDb, session: session_model.Session) -> TestDb {
  TestDb(
    ..db,
    sessions: dict.insert(db.sessions, uuid_key(session.id), session),
    session_ids_by_token: dict.insert(
      db.session_ids_by_token,
      session.token,
      uuid_key(session.id),
    ),
    write_steps: ["create_session", ..db.write_steps],
  )
}

fn upsert_login_token(
  db: TestDb,
  login_token: login_token_model.LoginToken,
) -> TestDb {
  TestDb(
    ..db,
    login_tokens: dict.insert(
      db.login_tokens,
      uuid_key(login_token.id),
      login_token,
    ),
    write_steps: ["update_login_token", ..db.write_steps],
  )
}

fn delete_login_tokens_before(
  db: TestDb,
  before: timestamp.Timestamp,
) -> TestDb {
  let before_microseconds = timestamp_helpers.to_microseconds(before)
  let kept_login_tokens =
    db.login_tokens
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, login_token) = entry
      timestamp_helpers.to_microseconds(login_token.created_at)
      >= before_microseconds
    })
    |> dict.from_list

  TestDb(..db, login_tokens: kept_login_tokens)
}

fn put_job(db: TestDb, job: job_model.Job) -> TestDb {
  TestDb(..db, jobs: dict.insert(db.jobs, uuid_key(job.id), job))
}

fn delete_jobs_before_by_statuses(
  db: TestDb,
  before: timestamp.Timestamp,
  statuses: List(job_model.Status),
) -> TestDb {
  let before_microseconds = timestamp_helpers.to_microseconds(before)
  let kept_jobs =
    db.jobs
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, job) = entry
      let completed_at_microseconds =
        job.completed_at
        |> option.map(timestamp_helpers.to_microseconds)

      case completed_at_microseconds {
        option.Some(completed_at) ->
          case
            completed_at < before_microseconds
            && list.contains(statuses, job.status)
          {
            True -> False
            False -> True
          }
        _ -> True
      }
    })
    |> dict.from_list

  TestDb(..db, jobs: kept_jobs)
}

fn put_periodic_job(
  db: TestDb,
  periodic_job: periodic_job_model.PeriodicJob,
) -> TestDb {
  TestDb(
    ..db,
    periodic_jobs: dict.insert(
      db.periodic_jobs,
      uuid_key(periodic_job.id),
      periodic_job,
    ),
  )
}

fn insert_snippet(db: TestDb, snippet: snippet_model.Snippet) -> TestDb {
  TestDb(
    ..db,
    snippets: dict.insert(db.snippets, uuid_key(snippet.id), snippet),
  )
}

fn delete_sessions_by_account_id(db: TestDb, account_id: uuid.Uuid) -> TestDb {
  let kept_sessions =
    db.sessions
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, session) = entry
      !session_belongs_to_account(db, session, account_id)
    })
    |> dict.from_list
  let kept_session_ids_by_token =
    db.session_ids_by_token
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, session_id) = entry
      dict.get(kept_sessions, session_id) == Ok(find_session(db, session_id))
    })
    |> dict.from_list

  TestDb(
    ..db,
    sessions: kept_sessions,
    session_ids_by_token: kept_session_ids_by_token,
    deletion_steps: ["delete_sessions_by_account_id", ..db.deletion_steps],
  )
}

fn delete_users_by_account_id(db: TestDb, account_id: uuid.Uuid) -> TestDb {
  TestDb(
    ..db,
    users: remove_users_by_account_id(db.users, account_id),
    deletion_steps: ["delete_users_by_account_id", ..db.deletion_steps],
  )
}

fn delete_account_by_id(db: TestDb, account_id: uuid.Uuid) -> TestDb {
  TestDb(
    ..db,
    accounts: dict.delete(db.accounts, uuid_key(account_id)),
    deletion_steps: ["delete_account", ..db.deletion_steps],
  )
}

fn delete_session_by_id(db: TestDb, id: uuid.Uuid) -> TestDb {
  let session_key = uuid_key(id)
  let session_ids_by_token = case dict.get(db.sessions, session_key) {
    Ok(session) -> dict.delete(db.session_ids_by_token, session.token)
    Error(_) -> db.session_ids_by_token
  }

  TestDb(
    ..db,
    sessions: dict.delete(db.sessions, session_key),
    session_ids_by_token: session_ids_by_token,
  )
}

fn delete_job_by_id(db: TestDb, id: uuid.Uuid) -> TestDb {
  TestDb(..db, jobs: dict.delete(db.jobs, uuid_key(id)))
}

fn delete_snippet_by_id(db: TestDb, id: BitArray) -> TestDb {
  TestDb(..db, snippets: dict.delete(db.snippets, bit_array_key(id)))
}

fn delete_snippets_by_account_id(db: TestDb, account_id: uuid.Uuid) -> TestDb {
  TestDb(
    ..db,
    snippets: remove_snippets_by_account_id(db, account_id),
    deletion_steps: ["delete_snippets_by_account_id", ..db.deletion_steps],
  )
}

fn increment_user_action_count(db: TestDb) -> TestDb {
  TestDb(..db, user_action_count: db.user_action_count + 1, write_steps: [
    "create_user_action",
    ..db.write_steps
  ])
}

fn delete_user_actions_before(
  db: TestDb,
  before: timestamp.Timestamp,
) -> TestDb {
  let before_microseconds = timestamp_helpers.to_microseconds(before)
  let kept_user_actions =
    db.user_actions
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, user_action) = entry
      timestamp_helpers.to_microseconds(user_action.created_at)
      >= before_microseconds
    })
    |> dict.from_list

  TestDb(..db, user_actions: kept_user_actions)
}

fn remove_users_by_account_id(
  users: Dict(String, user_model.User),
  account_id: uuid.Uuid,
) -> Dict(String, user_model.User) {
  users
  |> dict.to_list
  |> list.filter(fn(entry) {
    let #(_, user) = entry
    user.account_id != account_id
  })
  |> dict.from_list
}

fn remove_snippets_by_account_id(
  db: TestDb,
  account_id: uuid.Uuid,
) -> Dict(String, snippet_model.Snippet) {
  db.snippets
  |> dict.to_list
  |> list.filter(fn(entry) {
    let #(_, snippet) = entry
    case dict.get(db.users, uuid_key(snippet.user_id)) {
      Ok(user) -> user.account_id != account_id
      Error(_) -> True
    }
  })
  |> dict.from_list
}

fn uuid_key(id: uuid.Uuid) -> String {
  uuid.to_string(id)
}

fn bit_array_key(id: BitArray) -> String {
  let assert Ok(uuid) = uuid.from_bit_array(id)
  uuid_key(uuid)
}

fn must_uuid(value: String) -> uuid.Uuid {
  let assert Ok(id) = uuid.from_string(value)
  id
}

fn test_request_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000001")
}

fn test_account_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000010")
}

fn test_email_address() -> email_address_model.EmailAddress {
  email_address_model.EmailAddress("user@example.com")
}

fn test_user_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000011")
}

fn test_session_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000012")
}

fn test_snippet_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000013")
}

fn test_timestamp() -> timestamp.Timestamp {
  timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0)
}

fn test_system_time() -> timestamp.Timestamp {
  timestamp.from_unix_seconds_and_nanoseconds(1_700_000_005, 0)
}

fn test_context() -> context.Context {
  let assert Ok(is_email) = regexp.from_string(".*")

  context.Context(
    config: context.Config(
      debug: False,
      encryption_key: "test",
      static_base_path: "/tmp",
      postgres: context.PostgresConfig(
        host: "localhost",
        port: 5432,
        db: "test",
        user: "test",
        pass: "test",
        pool_size: 1,
      ),
      docker_run: context.DockerRunConfig(
        base_url: "http://localhost",
        access_token: "test",
      ),
      auth: context.AuthConfig(
        login_token_max_age: 900,
        session_token_max_age: 86_400,
        session_cookie_max_age: 86_400,
      ),
      cleanup: context.CleanupConfig(
        api_log_retention_days: 30,
        page_log_retention_days: 30,
        pageview_log_retention_days: 30,
        job_log_retention_days: 30,
        jobs_retention_days: 30,
        login_tokens_retention_days: 30,
        user_actions_retention_days: 30,
      ),
      rate_limits: dict.new(),
    ),
    regexes: context.Regexes(is_email: is_email),
    request_id: uuid.nil,
    started_at: 0,
    timestamp: timestamp.system_time(),
    client_info: context.ClientInfo(
      session_token: option.None,
      ip: option.None,
      user_agent: option.None,
      referrer: option.None,
    ),
  )
}
