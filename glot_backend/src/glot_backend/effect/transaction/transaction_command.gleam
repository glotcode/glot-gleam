import glot_backend/effect/auth/auth
import glot_backend/effect/core/core
import glot_backend/effect/snippet/snippet

pub type TransactionCommand {
  CoreCommand(core.CoreCommand)
  AuthCommand(auth.AuthCommand)
  SnippetCommand(snippet.SnippetCommand)
}
