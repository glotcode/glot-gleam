import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/email/email_handlers
import glot_backend/effect/job/job_handlers
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/effect/user_action/user_action_handlers
import pog

pub type Handlers {
  Handlers(
    basic: basic_handlers.BasicHandlers,
    email: email_handlers.EmailHandlers,
    job: job_handlers.JobHandlers,
    auth: auth_handlers.AuthHandlers,
    snippet: snippet_handlers.SnippetHandlers,
    docker_run: docker_run_handlers.DockerRunHandlers,
    user_action: user_action_handlers.UserActionHandlers,
  )
}

pub fn new(db: pog.Connection) -> Handlers {
  Handlers(
    basic: basic_handlers.new(),
    email: email_handlers.new(),
    job: job_handlers.new(db),
    auth: auth_handlers.new(db),
    snippet: snippet_handlers.new(db),
    docker_run: docker_run_handlers.new(),
    user_action: user_action_handlers.new(db),
  )
}
