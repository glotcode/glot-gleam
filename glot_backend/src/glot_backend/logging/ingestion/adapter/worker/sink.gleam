import gleam/erlang/process
import glot_backend/logging/ingestion/ports/sink.{type Sink}
import glot_backend/logging/ingestion/worker/batcher/worker
import wisp

pub fn new(subject: process.Subject(worker.Message)) -> Sink {
  sink.Sink(
    write_api: fn(entry) { send(subject, worker.InsertApi(entry)) },
    write_page: fn(entry) { send(subject, worker.InsertPage(entry)) },
    write_pageview: fn(entry) { send(subject, worker.InsertPageview(entry)) },
    drain: fn() { worker.drain(subject) },
  )
}

fn send(
  subject: process.Subject(worker.Message),
  message: worker.Message,
) -> Nil {
  case process.subject_owner(subject) {
    Ok(_) -> process.send(subject, message)
    Error(_) -> wisp.log_error("Log worker unavailable")
  }
}
