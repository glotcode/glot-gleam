import glot_core/admin/snippet_dto
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  SnippetLoaded(api_response.Response(snippet_dto.GetSnippetResponse))
  DeleteClicked
  DeleteCancelled
  DeleteDialogClosed
  DeleteConfirmed
  DeleteFinished(Generation, api_response.Response(Nil))
}
