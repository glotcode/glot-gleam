import gleam/dict
import gleam/option
import gleam/regexp
import gleam/time/timestamp
import gleeunit
import glot_backend/context
import glot_backend/domain/shared/session_domain
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/basic/basic
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/email/email_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/interpreter
import glot_backend/effect/job/job_handlers
import glot_backend/effect/program
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/effect/user_action/user_action_handlers
import glot_backend/job
import glot_backend/log
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
  let handlers = test_handlers()
  let ctx = test_context()
  let measured_effect = {
    use _ <- program.and_then(basic_effect.info(log.new()))
    use _ <- program.and_then(basic_effect.info(log.new()))
    program.succeed("ok")
  }

  let #(run_result, state) =
    interpreter.run(measured_effect, handlers, option.None, ctx)

  assert run_result == Ok("ok")
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic.LogEffectName),
      duration_ns: first,
      ..,
    ),
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic.LogEffectName),
      duration_ns: second,
      ..,
    ),
  ] = state.effect_measurements
  assert first >= 0
  assert second >= 0
}

pub fn measures_effects_in_success_test() {
  let handlers = test_handlers()
  let ctx = test_context()
  let measured_effect = {
    use _ <- program.and_then(basic_effect.new_token(5))
    program.succeed("ok")
  }
  let #(run_result, state) =
    interpreter.run(measured_effect, handlers, option.None, ctx)

  assert run_result == Ok("ok")
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic.NewTokenEffectName),
      duration_ns: duration_ms,
      ..,
    ),
  ] = state.effect_measurements
  assert duration_ms >= 0
}

pub fn measures_effects_in_error_test() {
  let handlers = test_handlers()
  let ctx = test_context()
  let failing_effect = {
    use _ <- program.and_then(basic_effect.new_token(5))
    program.fail(error.EmailInvalidError("bad"))
  }
  let #(run_result, state) =
    interpreter.run(failing_effect, handlers, option.None, ctx)

  assert run_result == Error(error.EmailInvalidError("bad"))
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic.NewTokenEffectName),
      duration_ns: duration_ms,
      ..,
    ),
  ] = state.effect_measurements
  assert duration_ms >= 0
}

pub fn get_session_without_token_returns_none_test() {
  let handlers = test_handlers()
  let ctx = test_context()

  let #(run_result, _) =
    interpreter.run(session_domain.get_session(ctx), handlers, option.None, ctx)

  assert run_result == Ok(option.None)
}

pub fn get_session_with_missing_db_session_returns_none_test() {
  let handlers = test_handlers()
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
    interpreter.run(session_domain.get_session(ctx), handlers, option.None, ctx)

  assert run_result == Ok(option.None)
}

pub fn require_session_without_token_returns_missing_token_error_test() {
  let handlers = test_handlers()
  let ctx = test_context()

  let #(run_result, _) =
    interpreter.run(
      session_domain.require_session(ctx),
      handlers,
      option.None,
      ctx,
    )

  assert run_result == Error(error.SessionError(error.MissingSessionTokenError))
}

pub fn require_session_with_missing_db_session_returns_not_found_error_test() {
  let handlers = test_handlers()
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
    interpreter.run(
      session_domain.require_session(ctx),
      handlers,
      option.None,
      ctx,
    )

  assert run_result == Error(error.SessionError(error.SessionNotFoundError))
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
      get_next_job: fn(_: timestamp.Timestamp, _: job.Status) {
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
      create_session: fn(_) { Ok(Nil) },
      create_login_token: fn(_) { Ok(Nil) },
      update_login_token: fn(_) { Ok(Nil) },
    ),
    snippet: snippet_handlers.SnippetHandlers(
      get_snippet_by_id: fn(_) { Ok(option.None) },
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
  )
}

fn test_context() -> context.Context {
  let assert Ok(is_email) = regexp.from_string(".*")

  context.Context(
    config: context.Config(
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
