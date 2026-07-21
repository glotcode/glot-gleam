import glot_core/snippet/snippet_dto
import glot_frontend/api/response
import lustre/effect.{type Effect}

pub type Ports(msg) {
  Ports(
    load_ssr: fn(fn(String) -> msg) -> Effect(msg),
    list_public_snippets: fn(
      snippet_dto.ListPublicSnippetsRequest,
      fn(response.Response(snippet_dto.ListSnippetsResponse)) -> msg,
    ) -> Effect(msg),
    schedule: fn(Int, msg) -> Effect(msg),
  )
}
