import gleam/erlang/process

const timeout_ms = 2000

const poll_interval_ms = 5

const poll_attempts = 400

pub fn call(
  subject: process.Subject(message),
  make_message: fn(process.Subject(reply)) -> message,
) -> reply {
  process.call(subject, timeout_ms, make_message)
}

pub fn receive(subject: process.Subject(message)) -> message {
  let assert Ok(message) = process.receive(subject, timeout_ms)
  message
}

pub fn eventually(check: fn() -> value, satisfied: fn(value) -> Bool) -> value {
  eventually_loop(check, satisfied, poll_attempts)
}

fn eventually_loop(
  check: fn() -> value,
  satisfied: fn(value) -> Bool,
  attempts_remaining: Int,
) -> value {
  let value = check()

  case satisfied(value) {
    True -> value
    False -> {
      assert attempts_remaining > 0
      process.sleep(poll_interval_ms)
      eventually_loop(check, satisfied, attempts_remaining - 1)
    }
  }
}
