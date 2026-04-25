import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/erlang

pub fn run(
  effect: snippet_algebra.SnippetEffect(next_program),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
  ) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    snippet_algebra.GetSnippetById(id, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.snippet.get_snippet_by_id(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(snippet_algebra.GetSnippetByIdEffectName),
          effect_trace.DbReadEffectCategory,
          started_at,
        ),
      )
    }
    snippet_algebra.GetSnippetBySlug(slug, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.snippet.get_snippet_by_slug(slug)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(snippet_algebra.GetSnippetBySlugEffectName),
          effect_trace.DbReadEffectCategory,
          started_at,
        ),
      )
    }
    snippet_algebra.ListSnippets(
      visibilities: visibilities,
      skip_user_ids: skip_user_ids,
      cursor_slug: cursor_slug,
      limit: limit,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.snippet.list_snippets(
          visibilities,
          skip_user_ids,
          cursor_slug,
          limit,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(snippet_algebra.ListSnippetsEffectName),
          effect_trace.DbReadEffectCategory,
          started_at,
        ),
      )
    }
    snippet_algebra.DeleteSnippet(id, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.snippet.delete_snippet(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(snippet_algebra.DeleteSnippetEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    snippet_algebra.DeleteSnippetsByAccountId(account_id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.snippet.delete_snippets_by_account_id(account_id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(
            snippet_algebra.DeleteSnippetsByAccountIdEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    snippet_algebra.CreateSnippet(snippet_value, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.snippet.create_snippet(snippet_value)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(snippet_algebra.CreateSnippetEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    snippet_algebra.UpdateSnippet(snippet_value, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.snippet.update_snippet(snippet_value)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(snippet_algebra.UpdateSnippetEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
