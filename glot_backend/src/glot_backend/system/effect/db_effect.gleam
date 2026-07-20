import glot_backend/analytics/effect/algebra as analytics_algebra
import glot_backend/auth/effect/algebra as auth_algebra
import glot_backend/email/effect/template/algebra as email_template_algebra
import glot_backend/job/effect/algebra as job_algebra
import glot_backend/logging/effect/algebra as logging_algebra
import glot_backend/snippet/effect/algebra as snippet_algebra
import glot_backend/system/effect/program_types
import glot_backend/user_action/effect/algebra as user_action_algebra

pub fn map(
  effect: program_types.DbEffect(a),
  transform: fn(a) -> b,
) -> program_types.DbEffect(b) {
  case effect {
    program_types.AnalyticsEffect(effect) ->
      program_types.AnalyticsEffect(analytics_algebra.map(effect, transform))
    program_types.AuthEffect(effect) ->
      program_types.AuthEffect(auth_algebra.map(effect, transform))
    program_types.EmailTemplateEffect(effect) ->
      program_types.EmailTemplateEffect(email_template_algebra.map(
        effect,
        transform,
      ))
    program_types.JobEffect(effect) ->
      program_types.JobEffect(job_algebra.map(effect, transform))
    program_types.LoggingEffect(effect) ->
      program_types.LoggingEffect(logging_algebra.map(effect, transform))
    program_types.SnippetEffect(effect) ->
      program_types.SnippetEffect(snippet_algebra.map(effect, transform))
    program_types.UserActionEffect(effect) ->
      program_types.UserActionEffect(user_action_algebra.map(effect, transform))
  }
}
