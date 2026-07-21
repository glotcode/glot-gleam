import glot_core/snippet/snippet_dto
import glot_frontend/api/response
import glot_frontend/public/snippets/model.{type Request}

pub type Msg {
  EnvironmentLoaded(Request, String)
  SnippetsLoaded(Request, response.Response(snippet_dto.ListSnippetsResponse))
  LoadingDelayElapsed(Request, Int)
}
