import gleam/option
import glot_core/snippet/snippet_dto
import glot_frontend/account/snippets/command
import glot_frontend/account/snippets/loading_update
import glot_frontend/account/snippets/message.{
  DeleteCancelled, DeleteClicked, DeleteConfirmed, DeleteDialogClosed,
  DeleteFinished,
}
import glot_frontend/account/snippets/model.{type Model}
import glot_frontend/api/response as api_response

const dialog_id = "manage-snippets-page-delete-dialog"

pub fn update(state: Model, msg: message.Msg) {
  case msg {
    DeleteClicked(slug) ->
      case model.find_loaded_snippet(state, slug) {
        option.Some(snippet) -> #(
          model.Model(..state, pending_delete: option.Some(snippet)),
          command.OpenDialog(dialog_id),
        )
        option.None -> #(state, command.none())
      }
    DeleteCancelled -> #(state, command.CloseDialog(dialog_id))
    DeleteDialogClosed -> #(
      model.Model(..state, pending_delete: option.None),
      command.none(),
    )
    DeleteConfirmed(slug) -> #(
      model.Model(
        ..state,
        deleting_slug: option.Some(slug),
        mutation_error: option.None,
      ),
      command.batch([
        command.CloseDialog(dialog_id),
        command.DeleteSnippet(
          snippet_dto.DeleteSnippetRequest(slug:),
          fn(result) { DeleteFinished(slug, result) },
        ),
      ]),
    )
    DeleteFinished(slug, result) -> finished(state, slug, result)
    _ -> #(state, command.none())
  }
}

fn finished(state: Model, slug: String, result: api_response.Response(Nil)) {
  case state.deleting_slug == option.Some(slug), result {
    False, _ -> #(state, command.none())
    True, api_response.Success(_) -> loading_update.reload(state)
    True, api_response.ApiFailure(error) ->
      failed(state, api_response.error_message(error))
    True, api_response.HttpFailure(_) ->
      failed(state, "Could not delete snippet.")
  }
}

fn failed(state: Model, message: String) {
  #(
    model.Model(
      ..state,
      pending_delete: option.None,
      deleting_slug: option.None,
      mutation_error: option.Some(message),
    ),
    command.none(),
  )
}
