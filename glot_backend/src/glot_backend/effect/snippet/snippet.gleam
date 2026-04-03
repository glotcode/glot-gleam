import gleam/option
import glot_backend/effect/error
import glot_core/snippet/snippet_model.{type HydratedSnippet, type Snippet}

pub type SnippetEffect(next) {
  GetSnippetById(
    id: BitArray,
    next: fn(Result(option.Option(HydratedSnippet), error.DbQueryError)) -> next,
  )
  DeleteSnippet(
    id: BitArray,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  CreateSnippet(
    snippet: Snippet,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  UpdateSnippet(
    snippet: Snippet,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: SnippetEffect(a), f: fn(a) -> b) -> SnippetEffect(b) {
  case effect {
    GetSnippetById(id, next) ->
      GetSnippetById(id, next: fn(value) { f(next(value)) })
    DeleteSnippet(id, next) ->
      DeleteSnippet(id, next: fn(value) { f(next(value)) })
    CreateSnippet(snippet, next) ->
      CreateSnippet(snippet, next: fn(value) { f(next(value)) })
    UpdateSnippet(snippet, next) ->
      UpdateSnippet(snippet, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetSnippetByIdEffectName
  DeleteSnippetEffectName
  CreateSnippetEffectName
  UpdateSnippetEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetSnippetByIdEffectName -> "get_snippet_by_id"
    DeleteSnippetEffectName -> "delete_snippet"
    CreateSnippetEffectName -> "create_snippet"
    UpdateSnippetEffectName -> "update_snippet"
  }
}
