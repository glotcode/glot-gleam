import gleam/otp/static_supervisor as supervisor
import glot_backend/context
import glot_backend/job_worker
import pog

pub fn start(db: pog.Connection, config: context.Config, regexp: context.Regexp) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(job_worker.supervised(db, config, regexp))
  |> supervisor.start
}
