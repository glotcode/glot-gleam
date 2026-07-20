import gleam/erlang/process
import glot_backend/job/ports/tracker.{type Tracker}
import glot_backend/job/worker/tracker/worker as tracker_worker

pub fn new(subject: process.Subject(tracker_worker.Message)) -> Tracker {
  tracker.Tracker(
    started: fn() { tracker_worker.job_started(subject) },
    finished: fn() { tracker_worker.job_finished(subject) },
    count: fn() { tracker_worker.get_count(subject) },
  )
}
