import gleam/int
import gleam/option
import gleam/time/timestamp
import glot_backend/context
import glot_backend/domain/account/delete_account_domain
import glot_backend/domain/cleanup/clean_api_log_domain
import glot_backend/domain/cleanup/clean_jobs_domain
import glot_backend/domain/cleanup/clean_job_log_domain
import glot_backend/domain/cleanup/clean_login_tokens_domain
import glot_backend/domain/cleanup/clean_page_log_domain
import glot_backend/domain/cleanup/clean_pageview_log_domain
import glot_backend/domain/cleanup/clean_user_actions_domain
import glot_backend/domain/email/send_email_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/transaction/transaction_program
import glot_core/job/job_model

const base_backoff_seconds = 5

const max_backoff_seconds = 300

pub fn claim_next_job(
  ctx: context.Context,
) -> program_types.Program(option.Option(job_model.Job)) {
  transaction_effect.run({
    use maybe_job <- transaction_program.and_then(job_effect.get_next_job_tx(
      ctx.timestamp,
      job_model.Pending,
    ))

    case maybe_job {
      option.None -> transaction_program.succeed(option.None)
      option.Some(next_job) -> {
        let started_job = job_model.start(next_job, ctx.timestamp)
        use _ <- transaction_program.and_then(job_effect.update_job_tx(
          started_job,
        ))
        transaction_program.succeed(option.Some(started_job))
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
      use payload <- program.and_then(require_payload(job))
      use email <- program.and_then(send_email_domain.email_from_json(
        ctx,
        payload,
      ))
      send_email_domain.send_email(ctx, email)
    }
    job_model.DeleteAccountJob -> {
      use payload <- program.and_then(require_payload(job))
      use payload <- program.and_then(delete_account_domain.payload_from_json(
        payload,
      ))
      delete_account_domain.delete_account(ctx, payload)
    }
    job_model.CleanApiLogJob -> clean_api_log_domain.clean_api_log(ctx)
    job_model.CleanPageLogJob -> clean_page_log_domain.clean_page_log(ctx)
    job_model.CleanPageviewLogJob ->
      clean_pageview_log_domain.clean_pageview_log(ctx)
    job_model.CleanJobLogJob -> clean_job_log_domain.clean_job_log(ctx)
    job_model.CleanJobsJob -> clean_jobs_domain.clean_jobs(ctx)
    job_model.CleanLoginTokensJob ->
      clean_login_tokens_domain.clean_login_tokens(ctx)
    job_model.CleanUserActionsJob ->
      clean_user_actions_domain.clean_user_actions(ctx)
  }
}

fn require_payload(job: job_model.Job) -> program_types.Program(String) {
  case job.payload {
    option.Some(payload) -> program.succeed(payload)
    option.None ->
      program.fail(error.ValidationError(
        "Missing payload for job type: "
        <> job_model.job_type_to_string(job.job_type),
      ))
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
