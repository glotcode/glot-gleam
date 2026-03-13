import gleam/option
import gleam/time/timestamp
import gleeunit
import glot_backend/program
import glot_backend/sql

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
  let measured_program = {
    use _ <- program.and_then(program.measure_effect_duration(
      program.CustomEffect("custom"),
      3,
    ))
    use _ <- program.and_then(program.measure_effect_duration(
      program.CustomEffect("custom"),
      9,
    ))
    program.succeed("ok")
  }

  let #(run_result, program.State(effect_timings: effect_timings, log_fields: _)) =
    program.run(measured_program, handlers)

  assert run_result == Ok("ok")
  assert effect_timings
    == [
      #(program.CustomEffect("custom"), 3),
      #(program.CustomEffect("custom"), 9),
    ]
}

pub fn measures_effects_in_success_test() {
  let handlers = test_handlers()
  let measured_program = {
    use _ <- program.and_then(program.random_string(5))
    program.succeed("ok")
  }
  let #(run_result, program.State(effect_timings: effect_timings, log_fields: _)) =
    program.run(measured_program, handlers)

  assert run_result == Ok("ok")
  let assert [#(program.RandomStringEffect, duration_ms)] = effect_timings
  assert duration_ms >= 0
}

pub fn measures_effects_in_error_test() {
  let handlers = test_handlers()
  let failing_program = {
    use _ <- program.and_then(program.random_string(5))
    program.fail(program.EmailInvalidError("bad"))
  }
  let #(run_result, program.State(effect_timings: effect_timings, log_fields: _)) =
    program.run(failing_program, handlers)

  assert run_result == Error(program.EmailInvalidError("bad"))
  let assert [#(program.RandomStringEffect, duration_ms)] = effect_timings
  assert duration_ms >= 0
}

fn test_handlers() -> program.Handlers {
  program.Handlers(
    random_string: fn(_) { "random" },
    system_time: timestamp.system_time,
    uuid_v7: fn() { <<0>> },
    post_run_request: fn(_, _) {
      Error(program.InternalRunRequestError("unused in test"))
    },
    send_email: fn(_) { Error(program.InternalSendEmailError("unused in test")) },
    get_user_by_email: fn(_) { Ok([]) },
    get_next_job: fn(_) { Ok(option.None) },
    count_user_activities_by_ip_and_action: fn(
      _: timestamp.Timestamp,
      _: option.Option(String),
      _: sql.UserAction,
    ) {
      Ok([])
    },
    run_command: fn(_) { Ok(Nil) },
    run_in_transaction: fn(_) { Ok(Nil) },
  )
}
