import glot_backend/effect/app_config/app_config_handlers
import glot_backend/effect/analytics/analytics_handlers
import glot_backend/effect/api_log/api_log_handlers
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/email/email_handlers
import glot_backend/effect/get_language_version/get_language_version_handlers
import glot_backend/effect/job/job_handlers
import glot_backend/effect/job_log/job_log_handlers
import glot_backend/effect/page_log/page_log_handlers
import glot_backend/effect/pageview_log/pageview_log_handlers
import glot_backend/effect/periodic_job/periodic_job_handlers
import glot_backend/effect/run_log/run_log_handlers
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/effect/transaction/transaction_handlers
import glot_backend/effect/user_action/user_action_handlers
import pog

pub type Handlers {
  Handlers(
    app_config: app_config_handlers.AppConfigHandlers,
    api_log: api_log_handlers.ApiLogHandlers,
    analytics: analytics_handlers.AnalyticsHandlers,
    basic: basic_handlers.BasicHandlers,
    email: email_handlers.EmailHandlers,
    get_language_version: get_language_version_handlers.GetLanguageVersionHandlers,
    job: job_handlers.JobHandlers,
    job_log: job_log_handlers.JobLogHandlers,
    page_log: page_log_handlers.PageLogHandlers,
    pageview_log: pageview_log_handlers.PageviewLogHandlers,
    periodic_job: periodic_job_handlers.PeriodicJobHandlers,
    run_log: run_log_handlers.RunLogHandlers,
    auth: auth_handlers.AuthHandlers,
    snippet: snippet_handlers.SnippetHandlers,
    docker_run: docker_run_handlers.DockerRunHandlers,
    user_action: user_action_handlers.UserActionHandlers,
    transaction: transaction_handlers.TransactionHandlers,
  )
}

pub fn new(db: pog.Connection) -> Handlers {
  Handlers(
    app_config: app_config_handlers.new(db),
    api_log: api_log_handlers.new(db),
    analytics: analytics_handlers.new(db),
    basic: basic_handlers.new(),
    email: email_handlers.new(),
    get_language_version: get_language_version_handlers.new(),
    job: job_handlers.new(db),
    job_log: job_log_handlers.new(db),
    page_log: page_log_handlers.new(db),
    pageview_log: pageview_log_handlers.new(db),
    periodic_job: periodic_job_handlers.new(db),
    run_log: run_log_handlers.new(db),
    auth: auth_handlers.new(db),
    snippet: snippet_handlers.new(db),
    docker_run: docker_run_handlers.new(),
    user_action: user_action_handlers.new(db),
    transaction: transaction_handlers.new(db),
  )
}
