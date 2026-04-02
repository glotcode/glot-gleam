import glot_backend/context
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/core/core_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/error
import glot_backend/effect/effect_model
import glot_backend/effect/job/job_handlers
import glot_backend/effect/program_state
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/effect/transaction/transaction_handlers

pub type Handlers {
  Handlers(
    core: core_handlers.CoreHandlers,
    job: job_handlers.JobHandlers,
    auth: auth_handlers.AuthHandlers,
    snippet: snippet_handlers.SnippetHandlers,
    docker_run: docker_run_handlers.DockerRunHandlers,
    transaction: transaction_handlers.TransactionHandlers,
  )
}

pub fn from_context(
  ctx: context.Context,
  run_in_transaction: fn(List(effect_model.Program(Nil))) ->
    #(Result(Nil, error.DbTransactionError), program_state.State),
) -> Handlers {
  Handlers(
    core: core_handlers.from_context(ctx),
    job: job_handlers.from_context(ctx),
    auth: auth_handlers.from_context(ctx),
    snippet: snippet_handlers.from_context(ctx),
    docker_run: docker_run_handlers.from_context(ctx),
    transaction: transaction_handlers.from_runner(run_in_transaction),
  )
}
