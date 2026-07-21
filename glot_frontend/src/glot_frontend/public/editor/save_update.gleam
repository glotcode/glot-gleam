import gleam/option
import glot_core/route
import glot_frontend/api/response as api_response
import glot_frontend/public/editor/command
import glot_frontend/public/editor/draft_workflow
import glot_frontend/public/editor/execution
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{
  type Msg, RestoreDraftAccepted, RestoreDraftClosed, RestoreDraftDeclined,
  SaveCancelled, SaveClicked, SaveConfirmed, SaveDialogClosed, SaveFinished,
  SaveVisibilityDraftSelected, SnippetInfoClicked, SnippetInfoClosed,
  SnippetInfoDismissed,
}
import glot_frontend/public/editor/model.{type RealModel, RealModel}
import glot_frontend/public/editor/policy
import glot_frontend/public/editor/save_workflow
import youid/uuid.{type Uuid}

pub fn update(
  model: RealModel,
  msg: Msg,
  current_user_id: option.Option(Uuid),
) -> #(RealModel, command.Command(Msg)) {
  case msg {
    SaveClicked ->
      case
        model.slug,
        current_user_id,
        policy.is_owner(model, current_user_id)
      {
        option.Some(_), option.Some(_), True ->
          save_workflow.save_snippet(model, current_user_id, False)
        _, _, _ -> #(
          RealModel(..model, save_visibility_draft: model.visibility),
          command.OpenDialog(ids.save_dialog),
        )
      }

    SaveVisibilityDraftSelected(visibility) -> #(
      RealModel(..model, save_visibility_draft: visibility),
      command.none(),
    )

    SaveCancelled -> #(
      reset_save_dialog_draft(model),
      command.CloseDialog(ids.save_dialog),
    )

    SaveDialogClosed -> #(reset_save_dialog_draft(model), focus_editor())

    RestoreDraftAccepted -> {
      case model.pending_restore_draft {
        option.Some(draft) -> #(
          draft_workflow.apply_editor_draft(model, draft.draft),
          command.CloseDialog(ids.restore_draft_dialog),
        )

        option.None -> #(model, command.none())
      }
    }

    RestoreDraftDeclined -> #(
      RealModel(..model, pending_restore_draft: option.None),
      command.batch([
        command.CloseDialog(ids.restore_draft_dialog),
        command.ClearDraft(model),
      ]),
    )

    RestoreDraftClosed -> #(
      RealModel(..model, pending_restore_draft: option.None),
      focus_editor(),
    )

    SnippetInfoClicked -> #(model, command.OpenDialog(ids.snippet_info_dialog))

    SnippetInfoDismissed -> #(
      model,
      command.CloseDialog(ids.snippet_info_dialog),
    )

    SnippetInfoClosed -> #(model, focus_editor())

    SaveConfirmed -> save_workflow.save_snippet(model, current_user_id, True)

    SaveFinished(generation, _) if generation != model.save_generation -> #(
      model,
      command.none(),
    )

    SaveFinished(_, result) -> {
      case result {
        api_response.Success(response) -> {
          let next_model =
            RealModel(..model, save_state: execution.Saved(response.slug))
          let clear_draft_command = command.ClearDraft(next_model)
          case policy.save_operation(model, current_user_id) {
            policy.UpdateSnippet(_) -> #(next_model, clear_draft_command)
            policy.CreateSnippet -> {
              let navigate =
                command.Navigate(
                  route.to_string(route.Public(route.Snippet(response.slug))),
                )
              #(next_model, command.batch([clear_draft_command, navigate]))
            }
          }
        }

        api_response.ApiFailure(error) -> #(
          RealModel(
            ..model,
            save_state: execution.SaveError(api_response.error_message(error)),
          ),
          command.none(),
        )

        api_response.HttpFailure(_) -> #(
          RealModel(
            ..model,
            save_state: execution.SaveError(
              "Could not complete "
              <> policy.action_name(model, current_user_id)
              <> ".",
            ),
          ),
          command.none(),
        )
      }
    }
    _ -> #(model, command.none())
  }
}

fn focus_editor() -> command.Command(msg) {
  command.Focus(ids.editor)
}

fn reset_save_dialog_draft(model: RealModel) -> RealModel {
  RealModel(..model, save_visibility_draft: model.visibility)
}
