import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_core/snippet
import youid/uuid.{type Uuid}

pub type SnippetCommandName {
  InsertSnippetCommand
}

pub type SnippetCommand {
  InsertSnippet(
    id: Uuid,
    user_id: Uuid,
    snippet: snippet.Snippet,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub type SnippetEffect(next) {
  RunCommand(
    SnippetCommand,
    fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: SnippetEffect(a), f: fn(a) -> b) -> SnippetEffect(b) {
  case effect {
    RunCommand(command, next) -> RunCommand(command, fn(value) { f(next(value)) })
  }
}

pub fn command_name(command: SnippetCommand) -> SnippetCommandName {
  case command {
    InsertSnippet(_, _, _, _, _) -> InsertSnippetCommand
  }
}
