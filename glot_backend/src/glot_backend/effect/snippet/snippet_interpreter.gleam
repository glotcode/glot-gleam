import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/effect/snippet/snippet
import glot_backend/erlang

pub fn run(
  effect: snippet.SnippetEffect(effect_model.Program(a)),
  handlers: handlers_types.Handlers,
  state: effect_model.State,
  continue: fn(effect_model.Program(a), effect_model.State) ->
    #(Result(a, error.Error), effect_model.State),
  measure: fn(effect_model.State, effect_model.EffectName, Int) ->
    effect_model.State,
) -> #(Result(a, error.Error), effect_model.State) {
  case effect {
    snippet.InsertSnippet(id, user_id, snippet_value, created_at, updated_at, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.insert_snippet(
          id,
          user_id,
          snippet_value,
          created_at,
          updated_at,
        )
      continue(
        next(result),
        measure(
          state,
          effect_model.RunCommandEffect(
            effect_model.SnippetCommandName(snippet.InsertSnippetCommand),
          ),
          started_at,
        ),
      )
    }
  }
}
