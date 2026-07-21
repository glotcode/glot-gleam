import gleam/option
import glot_core/language
import glot_frontend/public/editor/command
import glot_frontend/public/editor/draft_workflow
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{
  type Msg, ExistingDraftLoaded, NewDraftLoaded,
}
import glot_frontend/public/editor/model.{type RealModel, RealModel}
import youid/uuid.{type Uuid}

pub fn update(
  model: RealModel,
  msg: Msg,
  _current_user_id: option.Option(Uuid),
) -> #(RealModel, command.Command(Msg)) {
  case msg {
    NewDraftLoaded(language_slug, stored) ->
      case
        model.slug == option.None
        && language.to_string(model.language) == language_slug
      {
        True -> {
          let next_model = RealModel(..model, pending_restore_draft: stored)
          let next_command = case stored {
            option.Some(_) ->
              command.OpenDialogNextFrame(ids.restore_draft_dialog)
            option.None -> command.none()
          }
          #(next_model, next_command)
        }
        False -> #(model, command.none())
      }

    ExistingDraftLoaded(slug, updated_at, stored) ->
      draft_workflow.apply_loaded_draft(model, slug, updated_at, stored)

    _ -> #(model, command.none())
  }
}
