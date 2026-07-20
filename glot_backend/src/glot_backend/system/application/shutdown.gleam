import gleam/erlang/process
import gleam/int
import gleam/io
import glot_backend/job/ports/tracker.{type Tracker}
import glot_backend/logging/ingestion/ports/sink.{type Sink}
import glot_backend/system/lifecycle/request_tracker/ports/request_tracker.{
  type RequestTracker,
}
import glot_backend/system/lifecycle/server_mode/ports/controller.{
  type Controller,
}
import glot_backend/system/runtime/erlang
import wisp

const drain_poll_interval_ms = 100

const drain_timeout_ms = 30_000

pub type SignalMessage {
  SigtermReceived
}

pub fn wait_for_signal(
  signal_subject: process.Subject(SignalMessage),
  log_sink: Sink,
  server_mode: Controller,
  request_tracker: RequestTracker,
  job_tracker: Tracker,
) -> Nil {
  case process.receive_forever(signal_subject) {
    SigtermReceived -> {
      wisp.log_warning("SIGTERM received")
      server_mode.enter_shutting_down()
      wisp.log_warning("Server mode changed to ShuttingDown")
      drain_work(request_tracker, job_tracker, log_sink, drain_timeout_ms)
    }
  }
}

fn drain_work(
  request_tracker: RequestTracker,
  job_tracker: Tracker,
  log_sink: Sink,
  remaining_ms: Int,
) -> Nil {
  let in_flight_request_count = request_tracker.count()
  let in_flight_job_count = job_tracker.count()
  let total_in_flight_count = in_flight_request_count + in_flight_job_count

  case total_in_flight_count == 0 {
    True -> {
      log_sink.drain()
      io.println("No in-flight requests, jobs, or logs remain, shutting down")
      erlang.halt()
    }
    False -> {
      case remaining_ms <= 0 {
        True -> {
          io.println(
            "Graceful shutdown timed out with "
            <> int.to_string(in_flight_request_count)
            <> " in-flight requests and "
            <> int.to_string(in_flight_job_count)
            <> " in-flight jobs remaining",
          )
          erlang.halt()
        }
        False -> {
          process.sleep(drain_poll_interval_ms)
          drain_work(
            request_tracker,
            job_tracker,
            log_sink,
            remaining_ms - drain_poll_interval_ms,
          )
        }
      }
    }
  }
}
