import gleam/option
import gleam/time/timestamp
import gleeunit
import glot_backend/api_action
import glot_backend/job
import glot_backend/effect
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
    use _ <- effect.and_then(effect.measure_effect_duration(
      effect.CustomEffect("custom"),
      3,
    ))
    use _ <- effect.and_then(effect.measure_effect_duration(
      effect.CustomEffect("custom"),
      9,
    ))
    effect.succeed("ok")
  }

  let #(run_result, state) = effect.run(measured_effect, handlers)

  assert run_result == Ok("ok")
  assert state.effect_timings
    == [
      #(effect.CustomEffect("custom"), 3),
      #(effect.CustomEffect("custom"), 9),
    ]
}

pub fn measures_effects_in_success_test() {
  let handlers = test_handlers()
  let measured_effect = {
    use _ <- effect.and_then(effect.new_token(5))
    effect.succeed("ok")
  }
  let #(run_result, state) = effect.run(measured_effect, handlers)

  assert run_result == Ok("ok")
  let assert [#(effect.NewTokenEffect, duration_ms)] = state.effect_timings
  assert duration_ms >= 0
}

pub fn measures_effects_in_error_test() {
  let handlers = test_handlers()
  let failing_effect = {
    use _ <- effect.and_then(effect.new_token(5))
    effect.fail(effect.EmailInvalidError("bad"))
  }
  let #(run_result, state) = effect.run(failing_effect, handlers)

  assert run_result == Error(effect.EmailInvalidError("bad"))
  let assert [#(effect.NewTokenEffect, duration_ms)] = state.effect_timings
  assert duration_ms >= 0
}

fn test_handlers() -> effect.Handlers {
  effect.Handlers(
    new_token: fn(_) { "random" },
    system_time: timestamp.system_time,
    uuid_v7: fn() { uuid.nil },
    post_run_request: fn(_, _) {
      Error(effect.InternalRunRequestError("unused in test"))
    },
    send_email: fn(_) {
      Error(effect.InternalSendEmailError("unused in test"))
  },
    get_user_by_email: fn(_) { Ok(option.None) },
    list_login_tokens_by_user: fn(_, _) { Ok([]) },
    get_session_by_token: fn(_) { Ok(option.None) },
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
    run_command: fn(_) { Ok(Nil) },
    run_in_transaction: fn(_) { Ok(Nil) },
  )
}
