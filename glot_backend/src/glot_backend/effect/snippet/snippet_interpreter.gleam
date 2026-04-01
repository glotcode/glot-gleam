import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/effect/program_state
import glot_backend/effect/snippet/snippet
import glot_backend/erlang

pub fn run(
  effect: snippet.SnippetEffect(effect_model.Program(a)),
  handlers: handlers_types.Handlers,
  state: program_state.State,
  continue: fn(effect_model.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    snippet.InsertSnippet(id, user_id, snippet_value, created_at, updated_at, next) -> {
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
        program_state.measure_effect(
          state,
          effect_model.SnippetEffectName(snippet.InsertSnippetEffectName),
          effect_model.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
