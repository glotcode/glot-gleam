import glot_backend/context
import glot_backend/effect/auth/auth_interpreter
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/job/job_interpreter
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_interpreter
import glot_backend/effect/user_action/user_action_interpreter

pub fn run(
  effect: program_types.DbEffect(next_program),
  ctx: context.Context,
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    program_types.AuthEffect(effect) ->
      auth_interpreter.run(effect, ctx, handlers, state, continue)
    program_types.JobEffect(effect) ->
      job_interpreter.run(effect, handlers, state, continue)
    program_types.SnippetEffect(effect) ->
      snippet_interpreter.run(effect, handlers, state, continue)
    program_types.UserActionEffect(effect) ->
      user_action_interpreter.run(effect, handlers, state, continue)
  }
}
