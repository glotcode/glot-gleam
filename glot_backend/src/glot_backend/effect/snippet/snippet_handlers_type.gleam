import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_core/snippet
import youid/uuid.{type Uuid}

pub type SnippetHandlers {
  SnippetHandlers(
    insert_snippet: fn(
      Uuid,
      Uuid,
      snippet.Snippet,
      Timestamp,
      Timestamp,
    ) -> Result(Nil, error.DbCommandError),
  )
}
