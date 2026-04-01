import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_core/snippet
import youid/uuid.{type Uuid}

pub type SnippetEffect(next) {
  InsertSnippet(
    id: Uuid,
    user_id: Uuid,
    snippet: snippet.Snippet,
    created_at: Timestamp,
    updated_at: Timestamp,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: SnippetEffect(a), f: fn(a) -> b) -> SnippetEffect(b) {
  case effect {
    InsertSnippet(id, user_id, snippet, created_at, updated_at, next) ->
      InsertSnippet(
        id,
        user_id,
        snippet,
        created_at,
        updated_at,
        next: fn(value) { f(next(value)) },
      )
  }
}

pub type EffectName {
  InsertSnippetEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    InsertSnippetEffectName -> "insert_snippet"
  }
}
