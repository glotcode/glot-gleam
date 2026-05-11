import glot_backend/effect/effect_trace
import glot_backend/effect/email_template/email_template_algebra
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: email_template_algebra.EmailTemplateEffect(next_program),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    email_template_algebra.GetEmailTemplateByName(name:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.email_template.get_email_template_by_name(name)

      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.EmailTemplateEffectName(
                email_template_algebra.GetEmailTemplateByNameEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.QueryError(query_error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.EmailTemplateEffectName(
              email_template_algebra.GetEmailTemplateByNameEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
  }
}
