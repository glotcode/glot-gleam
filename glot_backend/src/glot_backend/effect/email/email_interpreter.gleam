import glot_backend/context
import glot_backend/effect/effect_trace
import glot_backend/effect/email/email
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/erlang

pub fn run(
  effect: email.EmailEffect(program_types.Program(a)),
  _ctx: context.Context,
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    email.SendEmail(message, next) -> {
      let started_at = erlang.perf_counter_ns()
      let send_result = handlers.email.send_email(message)
      continue(
        next(send_result),
        program_state.add_effect_measurement(
          state,
          effect_trace.EmailEffectName(email.SendEmailEffectName),
          effect_trace.EmailEffectCategory,
          started_at,
        ),
      )
    }
  }
}
