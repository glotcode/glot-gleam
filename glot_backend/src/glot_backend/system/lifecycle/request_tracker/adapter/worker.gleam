import gleam/erlang/process
import glot_backend/system/lifecycle/request_tracker/ports/request_tracker.{
  type RequestTracker,
}
import glot_backend/system/lifecycle/request_tracker/worker

pub fn new(subject: process.Subject(worker.Message)) -> RequestTracker {
  request_tracker.RequestTracker(
    started: fn() { worker.request_started(subject) },
    finished: fn() { worker.request_finished(subject) },
    count: fn() { worker.get_count(subject) },
  )
}
