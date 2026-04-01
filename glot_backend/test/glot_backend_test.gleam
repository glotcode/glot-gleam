import gleam/option
import gleam/time/timestamp
import gleeunit
import glot_backend/api_action
import glot_backend/job
import glot_backend/effect/auth/auth_handlers_type
import glot_backend/effect/core/core
import glot_backend/effect/core/core_effect
import glot_backend/effect/core/core_handlers_type
import glot_backend/effect/docker_run/docker_run_handlers_type
import glot_backend/effect/interpreter
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_state
import glot_backend/effect/handlers_types
import glot_backend/effect/effect_model
import glot_backend/effect/snippet/snippet_handlers_type
import glot_backend/effect/transaction/transaction_handlers_type
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
  let measured_effect = {
    use _ <- program.and_then(core_effect.info(log.new()))
    use _ <- program.and_then(core_effect.info(log.new()))
    program.succeed("ok")
  }

  let #(run_result, state) = interpreter.run(measured_effect, handlers)

  assert run_result == Ok("ok")
  let assert [
    program_state.EffectTiming(
      name: effect_model.CoreEffectName(core.LogEffectName),
      duration_ns: first,
      ..
    ),
    program_state.EffectTiming(
      name: effect_model.CoreEffectName(core.LogEffectName),
      duration_ns: second,
      ..
    ),
  ] =
    state.effect_timings
  assert first >= 0
  assert second >= 0
}

pub fn measures_effects_in_success_test() {
  let handlers = test_handlers()
  let measured_effect = {
    use _ <- program.and_then(core_effect.new_token(5))
    program.succeed("ok")
  }
  let #(run_result, state) = interpreter.run(measured_effect, handlers)

  assert run_result == Ok("ok")
  let assert [
    program_state.EffectTiming(
      name: effect_model.CoreEffectName(core.NewTokenEffectName),
      duration_ns: duration_ms,
      ..
    ),
  ] = state.effect_timings
  assert duration_ms >= 0
}

pub fn measures_effects_in_error_test() {
  let handlers = test_handlers()
  let failing_effect = {
    use _ <- program.and_then(core_effect.new_token(5))
    program.fail(error.EmailInvalidError("bad"))
  }
  let #(run_result, state) = interpreter.run(failing_effect, handlers)

  assert run_result == Error(error.EmailInvalidError("bad"))
  let assert [
    program_state.EffectTiming(
      name: effect_model.CoreEffectName(core.NewTokenEffectName),
      duration_ns: duration_ms,
      ..
    ),
  ] = state.effect_timings
  assert duration_ms >= 0
}

fn test_handlers() -> handlers_types.Handlers {
  handlers_types.Handlers(
    core: core_handlers_type.CoreHandlers(
      new_token: fn(_) { "random" },
      system_time: timestamp.system_time,
      uuid_v7: fn() { uuid.nil },
      send_email: fn(_) {
        Error(error.InternalSendEmailError("unused in test"))
      },
      get_next_job: fn(_: timestamp.Timestamp, _: job.Status, _: job.Status) {
        Ok(option.None)
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
      insert_job: fn(_) { Ok(Nil) },
      insert_user_action: fn(_, _, _, _, _, _) { Ok(Nil) },
      mark_job_done: fn(_, _) { Ok(Nil) },
      reschedule_job: fn(_, _, _, _) { Ok(Nil) },
    ),
    auth: auth_handlers_type.AuthHandlers(
      get_user_by_email: fn(_) { Ok(option.None) },
      list_login_tokens_by_user: fn(_, _) { Ok([]) },
      get_session_by_token: fn(_) { Ok(option.None) },
      insert_user: fn(_, _, _) { Ok(Nil) },
      insert_session: fn(_, _, _, _, _, _) { Ok(Nil) },
      insert_login_token: fn(_, _, _, _, _) { Ok(Nil) },
      update_login_token: fn(_, _, _, _, _) { Ok(Nil) },
    ),
    snippet: snippet_handlers_type.SnippetHandlers(
      insert_snippet: fn(_, _, _, _, _) { Ok(Nil) },
    ),
    docker_run: docker_run_handlers_type.DockerRunHandlers(
      post_run_request: fn(_, _) {
        Error(error.InternalRunRequestError("unused in test"))
      },
    ),
    transaction: transaction_handlers_type.TransactionHandlers(
      run_in_transaction: fn(_) { #(Ok(Nil), program_state.new_state()) },
    ),
  )
}
