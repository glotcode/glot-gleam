import glot_core/snippet/snippet_dto
import glot_frontend/api/response

pub type Command(msg) {
  None
  Batch(List(Command(msg)))
  LoadSsr(fn(String) -> msg)
  ListPublicSnippets(
    snippet_dto.ListPublicSnippetsRequest,
    fn(response.Response(snippet_dto.ListSnippetsResponse)) -> msg,
  )
  Schedule(Int, msg)
}

pub fn none() -> Command(msg) {
  None
}

pub fn batch(commands: List(Command(msg))) -> Command(msg) {
  Batch(commands)
}
