import gleam/dict
import gleam/option
import gleam/regexp
import gleam/time/timestamp
import gleeunit
import glot_backend/context
import glot_backend/domain/shared/session_domain
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/email/email_handlers
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/interpreter
import glot_backend/effect/job/job_handlers
import glot_backend/effect/program
import glot_backend/effect/runtime
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/effect/transaction/transaction_handlers
import glot_backend/effect/user_action/user_action_handlers
import glot_backend/log
import glot_core/job/job_model
import glot_core/language
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_core/snippet/snippet_spam
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"

  assert greeting == "Hello, Joe!"
}

pub fn measurement_aggregation_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()
  let measured_effect = {
    use _ <- program.and_then(basic_effect.info(log.new()))
    use _ <- program.and_then(basic_effect.info(log.new()))
    program.succeed("ok")
  }

  let #(run_result, state) =
    interpreter.run(measured_effect, effect_runtime, ctx)

  assert run_result == Ok("ok")
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.LogEffectName(log.Info)),
      duration_ns: first,
      ..,
    ),
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.LogEffectName(log.Info)),
      duration_ns: second,
      ..,
    ),
  ] = state.effect_measurements
  assert first >= 0
  assert second >= 0
}

pub fn measures_effects_in_success_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()
  let measured_effect = {
    use _ <- program.and_then(basic_effect.new_token(5))
    program.succeed("ok")
  }
  let #(run_result, state) =
    interpreter.run(measured_effect, effect_runtime, ctx)

  assert run_result == Ok("ok")
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.NewTokenEffectName),
      duration_ns: duration_ms,
      ..,
    ),
  ] = state.effect_measurements
  assert duration_ms >= 0
}

pub fn measures_effects_in_error_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()
  let failing_effect = {
    use _ <- program.and_then(basic_effect.new_token(5))
    program.fail(error.EmailInvalidError("bad"))
  }
  let #(run_result, state) =
    interpreter.run(failing_effect, effect_runtime, ctx)

  assert run_result == Error(error.EmailInvalidError("bad"))
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.NewTokenEffectName),
      duration_ns: duration_ms,
      ..,
    ),
  ] = state.effect_measurements
  assert duration_ms >= 0
}

pub fn suppressed_debug_log_is_not_stored_or_measured_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()
  let measured_effect = {
    use _ <- program.and_then(
      basic_effect.debug(
        log.from_list([log.string("debug_key", "debug_value")]),
      ),
    )
    program.succeed("ok")
  }

  let #(run_result, state) =
    interpreter.run(measured_effect, effect_runtime, ctx)

  assert run_result == Ok("ok")
  assert state.debug_fields == log.new()
  assert state.effect_measurements == []
}

pub fn get_session_without_token_returns_none_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()

  let #(run_result, _) =
    interpreter.run(session_domain.get_session(ctx), effect_runtime, ctx)

  assert run_result == Ok(option.None)
}

pub fn get_session_with_missing_db_session_returns_none_test() {
  let effect_runtime = test_runtime()
  let ctx =
    context.Context(
      ..test_context(),
      client_info: context.ClientInfo(
        session_token: option.Some("missing-session-token"),
        ip: option.None,
        user_agent: option.None,
      ),
    )

  let #(run_result, _) =
    interpreter.run(session_domain.get_session(ctx), effect_runtime, ctx)

  assert run_result == Ok(option.None)
}

pub fn require_session_without_token_returns_missing_token_error_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()

  let #(run_result, _) =
    interpreter.run(session_domain.require_session(ctx), effect_runtime, ctx)

  assert run_result == Error(error.SessionError(error.MissingSessionTokenError))
}

pub fn require_session_with_missing_db_session_returns_not_found_error_test() {
  let effect_runtime = test_runtime()
  let ctx =
    context.Context(
      ..test_context(),
      client_info: context.ClientInfo(
        session_token: option.Some("missing-session-token"),
        ip: option.None,
        user_agent: option.None,
      ),
    )

  let #(run_result, _) =
    interpreter.run(session_domain.require_session(ctx), effect_runtime, ctx)

  assert run_result == Error(error.SessionError(error.SessionNotFoundError))
}

pub fn snippet_spam_filter_allows_normal_code_test() {
  assert snippet_spam.ensure_clean(
    snippet_dto.SnippetData(
      title: "Hello world",
      language: language.Python,
      visibility: snippet_model.Public,
      stdin: "",
      run_command: "python main.py",
      files: [
        snippet_model.File(
          name: "main.py",
          content: "print(\"hello\")",
        ),
      ],
    ),
  ) == Ok(Nil)
}

pub fn snippet_spam_filter_blocks_obvious_spam_test() {
  let result =
    snippet_spam.ensure_clean(
      snippet_dto.SnippetData(
        title: "Earn money fast",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_command: "python main.py",
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

fn test_handlers() -> handlers.Handlers {
  handlers.Handlers(
    basic: basic_handlers.BasicHandlers(
      new_token: fn(_) { "random" },
      system_time: timestamp.system_time,
      uuid_v7: fn(_) { uuid.nil },
    ),
    email: email_handlers.EmailHandlers(send_email: fn(_) {
      Error(error.InternalSendEmailError("unused in test"))
    }),
    job: job_handlers.JobHandlers(
      get_next_job: fn(_: timestamp.Timestamp, _: job_model.Status) {
        Ok(option.None)
      },
      create_job: fn(_) { Ok(Nil) },
      update_job: fn(_) { Ok(Nil) },
    ),
    auth: auth_handlers.AuthHandlers(
      get_user_by_email: fn(_, _) { Ok(option.None) },
      list_login_tokens_by_user: fn(_, _) { Ok([]) },
      get_session_by_token: fn(_, _) { Ok(option.None) },
      create_user: fn(_) { Ok(Nil) },
      update_user: fn(_) { Ok(Nil) },
      create_session: fn(_) { Ok(Nil) },
      create_login_token: fn(_) { Ok(Nil) },
      update_login_token: fn(_) { Ok(Nil) },
    ),
    snippet: snippet_handlers.SnippetHandlers(
      get_snippet_by_id: fn(_) { Ok(option.None) },
      get_snippet_by_slug: fn(_) { Ok(option.None) },
      delete_snippet: fn(_) { Ok(Nil) },
      create_snippet: fn(_) { Ok(Nil) },
      update_snippet: fn(_) { Ok(Nil) },
    ),
    docker_run: docker_run_handlers.DockerRunHandlers(run_code: fn(_, _) {
      Error(error.InternalRunRequestError("unused in test"))
    }),
    user_action: user_action_handlers.UserActionHandlers(
      count_user_actions: fn(_) { Ok([]) },
      create_user_action: fn(_) { Ok(Nil) },
    ),
    transaction: transaction_handlers.none(),
  )
}

fn test_runtime() -> runtime.Runtime {
  runtime.from_handlers(test_handlers())
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
    ),
  )
}
