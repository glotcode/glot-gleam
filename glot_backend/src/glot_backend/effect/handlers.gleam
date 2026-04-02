import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/core/core_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/job/job_handlers
import glot_backend/effect/snippet/snippet_handlers
import pog

pub type Handlers {
  Handlers(
    core: core_handlers.CoreHandlers,
    job: job_handlers.JobHandlers,
    auth: auth_handlers.AuthHandlers,
    snippet: snippet_handlers.SnippetHandlers,
    docker_run: docker_run_handlers.DockerRunHandlers,
  )
}

pub fn new(db: pog.Connection) -> Handlers {
  Handlers(
    core: core_handlers.new(db),
    job: job_handlers.new(db),
    auth: auth_handlers.new(db),
    snippet: snippet_handlers.new(db),
    docker_run: docker_run_handlers.new(),
  )
}
