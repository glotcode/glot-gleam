import glot_backend/email/effect/template/algebra as email_template_algebra
import glot_backend/email/ports/template_store.{type TemplateStore}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: email_template_algebra.EmailTemplateEffect(next_program),
  store: TemplateStore,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    email_template_algebra.ListEmailTemplates(next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.list()

      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.EmailTemplateEffectName(
                email_template_algebra.ListEmailTemplatesEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.database_query_error(query_error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.EmailTemplateEffectName(
              email_template_algebra.ListEmailTemplatesEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    email_template_algebra.GetEmailTemplateByName(name:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get(name)

      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.EmailTemplateEffectName(
                email_template_algebra.GetEmailTemplateByNameEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(query_error) -> #(
          Error(error.database_query_error(query_error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.EmailTemplateEffectName(
              email_template_algebra.GetEmailTemplateByNameEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    email_template_algebra.UpdateEmailTemplate(template:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.update(template)

      case result {
        Ok(_) ->
          continue(
            next(Nil),
            program_state.add_effect_measurement(
              state,
              effect_trace.EmailTemplateEffectName(
                email_template_algebra.UpdateEmailTemplateEffectName,
              ),
              effect_trace.DatabaseWriteEffect,
              started_at,
            ),
          )
        Error(command_error) -> #(
          Error(error.database_command_error(command_error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.EmailTemplateEffectName(
              email_template_algebra.UpdateEmailTemplateEffectName,
            ),
            effect_trace.DatabaseWriteEffect,
            started_at,
          ),
        )
      }
    }
  }
}
