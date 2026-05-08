import gleam/option
import glot_backend/context
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/job/job_effect
import glot_backend/effect/periodic_job/periodic_job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/transaction/transaction_program
import glot_core/job/job_model
import glot_core/periodic_job/periodic_job_model
import youid/uuid

pub fn enqueue_next_due_periodic_job(
  ctx: context.Context,
) -> program_types.Program(Bool) {
  use maybe_periodic_job <- program.and_then(
    periodic_job_effect.get_next_periodic_job(ctx.timestamp),
  )

  case maybe_periodic_job {
    option.None -> program.succeed(False)
    option.Some(periodic_job) -> {
      use job_id <- program.and_then(basic_effect.uuid_v7())
      use _ <- program.and_then(
        enqueue_next_due_periodic_job_tx(ctx, job_id, periodic_job)
        |> transaction_effect.run()
        |> program.attempt(fn(enqueue_error) {
          let failed_periodic_job =
            periodic_job_model.enqueue_failed(
              periodic_job,
              error.to_string(enqueue_error),
              ctx.timestamp,
            )
          use _ <- program.and_then(
            periodic_job_effect.update_periodic_job(failed_periodic_job),
          )
          program.fail(enqueue_error)
        }),
      )
      program.succeed(True)
    }
  }
}

fn enqueue_next_due_periodic_job_tx(
  ctx: context.Context,
  job_id: uuid.Uuid,
  periodic_job: periodic_job_model.PeriodicJob,
) -> program_types.TransactionProgram(Nil) {
  let job =
    job_model.periodic_job_execution(
      job_id,
      ctx.timestamp,
      periodic_job.id,
      periodic_job.job_type,
      periodic_job.payload,
    )
  let updated_periodic_job =
    periodic_job_model.enqueued(periodic_job, ctx.timestamp)

  use _ <- transaction_program.and_then(job_effect.create_job_tx(job))
  use _ <- transaction_program.and_then(
    periodic_job_effect.update_periodic_job_tx(updated_periodic_job),
  )
  transaction_program.succeed(Nil)
}
