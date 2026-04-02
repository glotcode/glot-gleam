import gleam/option
import gleam/time/timestamp
import gleeunit
import glot_backend/api_action
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/core/core
import glot_backend/effect/core/core_effect
import glot_backend/effect/core/core_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/interpreter
import glot_backend/effect/job/job_handlers
import glot_backend/effect/program
import glot_backend/effect/program_state
import glot_backend/effect/runtime
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/job
import glot_backend/log
import glot_core/rate_limit
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
  let runtime = test_runtime()
  let measured_effect = {
    use _ <- program.and_then(core_effect.info(log.new()))
    use _ <- program.and_then(core_effect.info(log.new()))
    program.succeed("ok")
  }

  let #(run_result, state) = interpreter.run(measured_effect, handlers, runtime)

  assert run_result == Ok("ok")
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.CoreEffectName(core.LogEffectName),
      duration_ns: first,
      ..,
    ),
    effect_trace.EffectMeasurement(
      name: effect_trace.CoreEffectName(core.LogEffectName),
      duration_ns: second,
      ..,
    ),
  ] = state.effect_measurements
  assert first >= 0
  assert second >= 0
}

pub fn measures_effects_in_success_test() {
  let handlers = test_handlers()
  let runtime = test_runtime()
  let measured_effect = {
    use _ <- program.and_then(core_effect.new_token(5))
    program.succeed("ok")
  }
  let #(run_result, state) = interpreter.run(measured_effect, handlers, runtime)

  assert run_result == Ok("ok")
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.CoreEffectName(core.NewTokenEffectName),
      duration_ns: duration_ms,
      ..,
    ),
  ] = state.effect_measurements
  assert duration_ms >= 0
}

pub fn measures_effects_in_error_test() {
  let handlers = test_handlers()
  let runtime = test_runtime()
  let failing_effect = {
    use _ <- program.and_then(core_effect.new_token(5))
    program.fail(error.EmailInvalidError("bad"))
  }
  let #(run_result, state) = interpreter.run(failing_effect, handlers, runtime)

  assert run_result == Error(error.EmailInvalidError("bad"))
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.CoreEffectName(core.NewTokenEffectName),
      duration_ns: duration_ms,
      ..,
    ),
  ] = state.effect_measurements
  assert duration_ms >= 0
}

fn test_handlers() -> handlers.Handlers {
  handlers.Handlers(
    core: core_handlers.CoreHandlers(
      new_token: fn(_) { "random" },
      system_time: timestamp.system_time,
      uuid_v7: fn() { uuid.nil },
      send_email: fn(_) {
        Error(error.InternalSendEmailError("unused in test"))
      },
      count_user_actions_by_ip: fn(
        _: List(rate_limit.Window),
        _: option.Option(String),
        _: api_action.ApiAction,
      ) {
        Ok([])
      },
      count_user_actions_by_user: fn(
        _: List(rate_limit.Window),
        _: option.Option(uuid.Uuid),
        _: api_action.ApiAction,
      ) {
        Ok([])
      },
      insert_user_action: fn(_, _, _, _, _, _) { Ok(Nil) },
    ),
    job: job_handlers.JobHandlers(
      get_next_job: fn(_: timestamp.Timestamp, _: job.Status, _: job.Status) {
        Ok(option.None)
      },
      insert_job: fn(_) { Ok(Nil) },
      mark_job_done: fn(_, _) { Ok(Nil) },
      reschedule_job: fn(_, _, _, _) { Ok(Nil) },
    ),
    auth: auth_handlers.AuthHandlers(
      get_user_by_email: fn(_) { Ok(option.None) },
      list_login_tokens_by_user: fn(_, _) { Ok([]) },
      get_session_by_token: fn(_) { Ok(option.None) },
      insert_user: fn(_, _, _) { Ok(Nil) },
      insert_session: fn(_, _, _, _, _, _) { Ok(Nil) },
      insert_login_token: fn(_, _, _, _, _) { Ok(Nil) },
      update_login_token: fn(_, _, _, _, _) { Ok(Nil) },
    ),
    snippet: snippet_handlers.SnippetHandlers(
      insert_snippet: fn(_, _, _, _, _) { Ok(Nil) },
    ),
    docker_run: docker_run_handlers.DockerRunHandlers(
      post_run_request: fn(_, _) {
        Error(error.InternalRunRequestError("unused in test"))
      },
    ),
  )
}

fn test_runtime() -> runtime.Runtime {
  runtime.from_runner(fn(_) { #(Ok(Nil), program_state.new_state()) })
}
