import glot_core/snippet/snippet_dto
import glot_frontend/account/snippets/model.{type Request}
import glot_frontend/api/response

pub type Msg {
  SnippetsLoaded(Request, response.Response(snippet_dto.ListSnippetsResponse))
  LoadingDelayElapsed(Request, Int)
  NextPageClicked
  PreviousPageClicked
  DeleteClicked(String)
  DeleteCancelled
  DeleteDialogClosed
  DeleteConfirmed(String)
  DeleteFinished(String, response.Response(Nil))
}
