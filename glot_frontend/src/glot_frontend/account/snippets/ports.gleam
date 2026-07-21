import gleam/option
import glot_core/snippet/snippet_dto
import glot_frontend/api/response
import lustre/effect.{type Effect}

pub type Ports(msg) {
  Ports(
    list_snippets: fn(
      snippet_dto.ListSessionSnippetsRequest,
      fn(response.Response(snippet_dto.ListSnippetsResponse)) -> msg,
    ) -> Effect(msg),
    delete_snippet: fn(
      snippet_dto.DeleteSnippetRequest,
      fn(response.Response(Nil)) -> msg,
    ) -> Effect(msg),
    open_dialog: fn(String) -> Effect(msg),
    close_dialog: fn(String) -> Effect(msg),
    navigate: fn(String, option.Option(String)) -> Effect(msg),
    schedule: fn(Int, msg) -> Effect(msg),
  )
}
