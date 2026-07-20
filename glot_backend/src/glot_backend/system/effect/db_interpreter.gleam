import glot_backend/analytics/effect/interpreter as analytics_interpreter
import glot_backend/auth/effect/interpreter as auth_interpreter
import glot_backend/email/effect/template/interpreter as email_template_interpreter
import glot_backend/job/effect/interpreter as job_interpreter
import glot_backend/logging/effect/interpreter as logging_interpreter
import glot_backend/snippet/effect/interpreter as snippet_interpreter
import glot_backend/system/effect/database_ports
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/effect/program_types
import glot_backend/system/request/context
import glot_backend/user_action/effect/interpreter as user_action_interpreter

pub fn run(
  effect: program_types.DbEffect(next_program),
  ctx: context.Context,
  handlers: database_ports.DatabasePorts,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    program_types.AnalyticsEffect(effect) ->
      analytics_interpreter.run(
        effect,
        database_ports.analytics(handlers),
        state,
        continue,
      )
    program_types.AuthEffect(effect) ->
      auth_interpreter.run(
        effect,
        ctx,
        database_ports.auth(handlers),
        state,
        continue,
      )
    program_types.EmailTemplateEffect(effect) ->
      email_template_interpreter.run(
        effect,
        database_ports.email_template(handlers),
        state,
        continue,
      )
    program_types.JobEffect(effect) ->
      job_interpreter.run(effect, database_ports.job(handlers), state, continue)
    program_types.LoggingEffect(effect) ->
      logging_interpreter.run(
        effect,
        database_ports.logging(handlers),
        state,
        continue,
      )
    program_types.SnippetEffect(effect) ->
      snippet_interpreter.run(
        effect,
        database_ports.snippet(handlers),
        state,
        continue,
      )
    program_types.UserActionEffect(effect) ->
      user_action_interpreter.run(
        effect,
        database_ports.user_action(handlers),
        state,
        continue,
      )
  }
}
