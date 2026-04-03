import glot_backend/effect/error
import glot_core/snippet.{type Snippet}

pub type SnippetEffect(next) {
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
    CreateSnippet(snippet, next) ->
      CreateSnippet(snippet, next: fn(value) { f(next(value)) })
    UpdateSnippet(snippet, next) ->
      UpdateSnippet(snippet, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  CreateSnippetEffectName
  UpdateSnippetEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    CreateSnippetEffectName -> "create_snippet"
    UpdateSnippetEffectName -> "update_snippet"
  }
}
