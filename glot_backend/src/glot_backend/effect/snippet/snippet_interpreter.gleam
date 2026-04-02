import glot_backend/effect/program_types
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/effect/snippet/snippet
import glot_backend/erlang

pub fn run(
  effect: snippet.SnippetEffect(program_types.Program(a)),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    snippet.InsertSnippet(
      id,
      user_id,
      snippet_value,
      created_at,
      updated_at,
      next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.snippet.insert_snippet(
          id,
          user_id,
          snippet_value,
          created_at,
          updated_at,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(snippet.InsertSnippetEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
