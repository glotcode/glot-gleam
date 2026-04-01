import glot_backend/effect/auth/auth_handlers_type
import glot_backend/effect/core/core_handlers_type
import glot_backend/effect/docker_run/docker_run_handlers_type
import glot_backend/effect/snippet/snippet_handlers_type
import glot_backend/effect/transaction/transaction_handlers_type

pub type Handlers {
  Handlers(
    core: core_handlers_type.CoreHandlers,
    auth: auth_handlers_type.AuthHandlers,
    snippet: snippet_handlers_type.SnippetHandlers,
    docker_run: docker_run_handlers_type.DockerRunHandlers,
    transaction: transaction_handlers_type.TransactionHandlers,
  )
}
