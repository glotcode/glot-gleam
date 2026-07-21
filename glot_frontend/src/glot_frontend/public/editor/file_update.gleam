import gleam/option
import glot_frontend/public/editor/command
import glot_frontend/public/editor/document
import glot_frontend/public/editor/file_workflow
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{
  type Msg, AddEntryCancelled, AddEntryClicked, AddEntryDialogClosed,
  AddEntryFilenameChanged, AddEntryKindSelected, AddEntrySubmitted,
  EditEntryCancelled, EditEntryDeleted, EditEntryDialogClosed,
  EditEntryFilenameChanged, EditEntrySubmitted, SelectedTabActionClicked,
}
import glot_frontend/public/editor/model.{type RealModel, RealModel}
import youid/uuid.{type Uuid}

pub fn update(
  model: RealModel,
  msg: Msg,
  _current_user_id: option.Option(Uuid),
) -> #(RealModel, command.Command(Msg)) {
  case msg {
    AddEntryClicked -> #(
      RealModel(
        ..model,
        add_entry_kind: document.default_add_entry_kind(model.stdin),
        add_entry_filename: "",
      ),
      command.OpenDialog(ids.add_entry_dialog),
    )

    AddEntryKindSelected(kind) -> #(
      RealModel(..model, add_entry_kind: kind),
      command.none(),
    )

    AddEntryFilenameChanged(filename) -> #(
      RealModel(..model, add_entry_filename: filename),
      command.none(),
    )

    AddEntryCancelled -> #(
      file_workflow.reset_add_entry_draft(model),
      command.CloseDialog(ids.add_entry_dialog),
    )

    AddEntrySubmitted -> {
      case file_workflow.add_entry(model) {
        option.Some(next_model) -> #(
          next_model,
          command.batch([
            command.CloseDialog(ids.add_entry_dialog),
            command.SaveDraft(next_model),
          ]),
        )

        option.None -> #(model, command.none())
      }
    }

    AddEntryDialogClosed -> #(
      file_workflow.reset_add_entry_draft(model),
      focus_editor(),
    )

    SelectedTabActionClicked -> #(
      RealModel(
        ..model,
        edit_entry_filename: document.default_file_name(
          model.files,
          model.selected_tab,
        ),
      ),
      command.OpenDialog(ids.edit_entry_dialog),
    )

    EditEntryFilenameChanged(filename) -> #(
      RealModel(..model, edit_entry_filename: filename),
      command.none(),
    )

    EditEntryCancelled -> #(
      file_workflow.reset_edit_entry_draft(model),
      command.CloseDialog(ids.edit_entry_dialog),
    )

    EditEntrySubmitted -> {
      case file_workflow.rename_selected_file(model) {
        option.Some(next_model) -> #(
          next_model,
          command.batch([
            command.CloseDialog(ids.edit_entry_dialog),
            command.SaveDraft(next_model),
          ]),
        )

        option.None -> #(model, command.none())
      }
    }

    EditEntryDeleted -> {
      case file_workflow.delete_selected_entry(model) {
        option.Some(next_model) -> #(
          next_model,
          command.batch([
            command.CloseDialog(ids.edit_entry_dialog),
            command.SaveDraft(next_model),
          ]),
        )

        option.None -> #(model, command.none())
      }
    }

    EditEntryDialogClosed -> #(
      file_workflow.reset_edit_entry_draft(model),
      focus_editor(),
    )
    _ -> #(model, command.none())
  }
}

fn focus_editor() -> command.Command(msg) {
  command.Focus(ids.editor)
}
