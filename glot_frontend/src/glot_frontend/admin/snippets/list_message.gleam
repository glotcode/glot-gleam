import glot_core/admin/snippet_dto
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  SnippetsLoaded(
    Generation,
    api_response.Response(snippet_dto.ListSnippetsResponse),
  )
  UsernameFilterChanged(String)
  ApplyFilterClicked
  ClearFilterClicked
  NextPageClicked
  PreviousPageClicked
}
