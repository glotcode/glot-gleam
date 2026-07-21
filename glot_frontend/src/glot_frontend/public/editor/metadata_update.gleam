import glot_frontend/public/editor/command
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{
  type Msg, EditMetadataCancelled, EditMetadataClicked, EditMetadataDialogClosed,
  EditMetadataSubmitted, EditMetadataVisibilitySelected, TitleDraftChanged,
}
import glot_frontend/public/editor/model.{type RealModel, RealModel}
import youid/uuid.{type Uuid}

pub fn update(
  model: RealModel,
  msg: Msg,
  _current_user_id: option.Option(Uuid),
) -> #(RealModel, command.Command(Msg)) {
  case msg {
    EditMetadataClicked -> #(
      RealModel(
        ..model,
        title_draft: model.title,
        save_visibility_draft: model.visibility,
      ),
      command.OpenDialog(ids.edit_metadata_dialog),
    )

    TitleDraftChanged(title_draft) -> #(
      RealModel(..model, title_draft: title_draft),
      command.none(),
    )

    EditMetadataVisibilitySelected(visibility) -> #(
      RealModel(..model, save_visibility_draft: visibility),
      command.none(),
    )

    EditMetadataCancelled -> #(
      reset_edit_metadata_draft(model),
      command.CloseDialog(ids.edit_metadata_dialog),
    )

    EditMetadataSubmitted -> {
      let next_model =
        RealModel(
          ..model,
          title: model.title_draft,
          visibility: model.save_visibility_draft,
        )
      #(
        next_model,
        command.batch([
          command.CloseDialog(ids.edit_metadata_dialog),
          command.SaveDraft(next_model),
        ]),
      )
    }

    EditMetadataDialogClosed -> #(
      reset_edit_metadata_draft(model),
      focus_editor(),
    )
    _ -> #(model, command.none())
  }
}

fn focus_editor() -> command.Command(msg) {
  command.Focus(ids.editor)
}

fn reset_edit_metadata_draft(model: RealModel) -> RealModel {
  RealModel(
    ..model,
    title_draft: model.title,
    save_visibility_draft: model.visibility,
  )
}

import gleam/option
