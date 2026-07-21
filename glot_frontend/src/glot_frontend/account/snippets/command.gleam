import gleam/option
import glot_core/snippet/snippet_dto
import glot_frontend/api/response

pub type Command(msg) {
  None
  Batch(List(Command(msg)))
  ListSnippets(
    snippet_dto.ListSessionSnippetsRequest,
    fn(response.Response(snippet_dto.ListSnippetsResponse)) -> msg,
  )
  DeleteSnippet(
    snippet_dto.DeleteSnippetRequest,
    fn(response.Response(Nil)) -> msg,
  )
  OpenDialog(String)
  CloseDialog(String)
  Navigate(String, option.Option(String))
  Schedule(Int, msg)
}

pub fn none() -> Command(msg) {
  None
}

pub fn batch(commands: List(Command(msg))) -> Command(msg) {
  Batch(commands)
}
