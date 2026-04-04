import gleam/int
import gleam/option
import gleam/time/timestamp
import glot_backend/context
import glot_backend/domain/email/send_email_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_core/job/job_model

const base_backoff_seconds = 5

const max_backoff_seconds = 300

pub fn claim_next_job(
  ctx: context.Context,
) -> program_types.Program(option.Option(job_model.Job)) {
  transaction_effect.run({
    use maybe_job <- program.and_then(job_effect.get_next_job(
      ctx.timestamp,
      job_model.Pending,
    ))

    case maybe_job {
      option.None -> program.succeed(option.None)
      option.Some(next_job) -> {
        let started_job = job_model.start(next_job, ctx.timestamp)
        use _ <- program.and_then(job_effect.update_job(started_job))
        program.succeed(option.Some(started_job))
      }
    }
  })
}

pub fn process_job(
  ctx: context.Context,
  job: job_model.Job,
) -> program_types.Program(Nil) {
  use result <- program.and_then(delegate_job(ctx, job) |> program.to_result())
  case result {
    Ok(Nil) -> complete_job(job)
    Error(err) -> {
      use _ <- program.and_then(reschedule_job(job, err))
      program.fail(err)
    }
  }
}

fn delegate_job(
  ctx: context.Context,
  job: job_model.Job,
) -> program_types.Program(Nil) {
  case job.job_type {
    job_model.SendEmailJob -> {
      use email <- program.and_then(send_email_domain.email_from_json(
        ctx,
        job.payload,
      ))
      send_email_domain.send_email(ctx, email)
    }
  }
}

fn complete_job(j: job_model.Job) -> program_types.Program(Nil) {
  use now <- program.and_then(basic_effect.system_time())
  let completed_job = job_model.done(j, now)
  job_effect.update_job(completed_job)
}

fn reschedule_job(
  j: job_model.Job,
  err: error.Error,
) -> program_types.Program(Nil) {
  use now <- program.and_then(basic_effect.system_time())
  let rescheduled_job =
    job_model.reschedule(
      j,
      add_seconds(now, backoff_seconds(j.attempts)),
      option.Some(error.to_string(err)),
      now,
    )
  job_effect.update_job(rescheduled_job)
}

fn backoff_seconds(attempts: Int) -> Int {
  let exponent = int.max(attempts - 1, 0)
  let multiplier = power_of_two(exponent)
  int.min(base_backoff_seconds * multiplier, max_backoff_seconds)
}

fn power_of_two(exponent: Int) -> Int {
  case exponent <= 0 {
    True -> 1
    False -> 2 * power_of_two(exponent - 1)
  }
}

fn add_seconds(
  ts: timestamp.Timestamp,
  seconds_to_add: Int,
) -> timestamp.Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(seconds + seconds_to_add, nanos)
}
