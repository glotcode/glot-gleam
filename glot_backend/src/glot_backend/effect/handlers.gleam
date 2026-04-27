import glot_backend/effect/api_log/api_log_handlers
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/email/email_handlers
import glot_backend/effect/job/job_handlers
import glot_backend/effect/job_log/job_log_handlers
import glot_backend/effect/periodic_job/periodic_job_handlers
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/effect/transaction/transaction_handlers
import glot_backend/effect/user_action/user_action_handlers
import pog

pub type Handlers {
  Handlers(
    api_log: api_log_handlers.ApiLogHandlers,
    basic: basic_handlers.BasicHandlers,
    email: email_handlers.EmailHandlers,
    job: job_handlers.JobHandlers,
    job_log: job_log_handlers.JobLogHandlers,
    periodic_job: periodic_job_handlers.PeriodicJobHandlers,
    auth: auth_handlers.AuthHandlers,
    snippet: snippet_handlers.SnippetHandlers,
    docker_run: docker_run_handlers.DockerRunHandlers,
    user_action: user_action_handlers.UserActionHandlers,
    transaction: transaction_handlers.TransactionHandlers,
  )
}

pub fn new(db: pog.Connection) -> Handlers {
  Handlers(
    api_log: api_log_handlers.new(db),
    basic: basic_handlers.new(),
    email: email_handlers.new(),
    job: job_handlers.new(db),
    job_log: job_log_handlers.new(db),
    periodic_job: periodic_job_handlers.new(db),
    auth: auth_handlers.new(db),
    snippet: snippet_handlers.new(db),
    docker_run: docker_run_handlers.new(),
    user_action: user_action_handlers.new(db),
    transaction: transaction_handlers.new(db),
  )
}
