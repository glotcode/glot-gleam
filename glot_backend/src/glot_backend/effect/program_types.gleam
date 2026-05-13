import glot_backend/effect/admin_log/admin_log_algebra
import glot_backend/effect/analytics/analytics_algebra
import glot_backend/effect/api_log/api_log_algebra
import glot_backend/effect/app_config/app_config_algebra
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/email/email_algebra
import glot_backend/effect/email_template/email_template_algebra
import glot_backend/effect/error
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/job/job_algebra
import glot_backend/effect/job_log/job_log_algebra
import glot_backend/effect/job_type_policy/job_type_policy_algebra
import glot_backend/effect/page_log/page_log_algebra
import glot_backend/effect/pageview_log/pageview_log_algebra
import glot_backend/effect/periodic_job/periodic_job_algebra
import glot_backend/effect/run_log/run_log_algebra
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/effect/user_action/user_action_algebra

pub type Program(a) {
  Pure(a)
  Fail(error.Error)
  Impure(Effect(Program(a)))
  Attempt(program: Program(a), on_error: fn(error.Error) -> Program(a))
}

pub type TransactionProgram(a) {
  TxPure(a)
  TxFail(error.Error)
  TxImpure(DbEffect(TransactionProgram(a)))
}

pub type Effect(next) {
  AppConfigEffect(app_config_algebra.AppConfigEffect(next))
  BasicEffect(basic_algebra.BasicEffect(next))
  EmailEffect(email_algebra.EmailEffect(next))
  DockerRunEffect(docker_run_algebra.DockerRunEffect(next))
  GetLanguageVersionEffect(
    get_language_version_algebra.GetLanguageVersionEffect(next),
  )
  DbEffect(DbEffect(next))
  TransactionEffect(TransactionEffect(next))
}

pub type DbEffect(next) {
  ApiLogEffect(api_log_algebra.ApiLogEffect(next))
  AdminLogEffect(admin_log_algebra.AdminLogEffect(next))
  AnalyticsEffect(analytics_algebra.AnalyticsEffect(next))
  AuthEffect(auth_algebra.AuthEffect(next))
  EmailTemplateEffect(email_template_algebra.EmailTemplateEffect(next))
  JobEffect(job_algebra.JobEffect(next))
  JobLogEffect(job_log_algebra.JobLogEffect(next))
  JobTypePolicyEffect(job_type_policy_algebra.JobTypePolicyEffect(next))
  PageLogEffect(page_log_algebra.PageLogEffect(next))
  PageviewLogEffect(pageview_log_algebra.PageviewLogEffect(next))
  PeriodicJobEffect(periodic_job_algebra.PeriodicJobEffect(next))
  RunLogEffect(run_log_algebra.RunLogEffect(next))
  SnippetEffect(snippet_algebra.SnippetEffect(next))
  UserActionEffect(user_action_algebra.UserActionEffect(next))
}

pub type TransactionEffect(next) {
  Run(program: TransactionProgram(next))
}
