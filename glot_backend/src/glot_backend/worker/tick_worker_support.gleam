import gleam/erlang/process
import gleam/option

pub fn schedule(
  subject: process.Subject(message),
  delay_ms: Int,
  message: message,
) -> process.Timer {
  process.send_after(subject, delay_ms, message)
}

pub fn cancel(timer: option.Option(process.Timer)) -> Nil {
  case timer {
    option.Some(timer) -> {
      let _ = process.cancel_timer(timer)
      Nil
    }
    option.None -> Nil
  }
}

pub fn reschedule(
  timer: option.Option(process.Timer),
  subject: process.Subject(message),
  delay_ms: Int,
  message: message,
) -> process.Timer {
  cancel(timer)
  schedule(subject, delay_ms, message)
}

pub fn trigger_now(
  timer: option.Option(process.Timer),
  subject: process.Subject(message),
  message: message,
) -> Nil {
  cancel(timer)
  let _ = process.send(subject, message)
  Nil
}
