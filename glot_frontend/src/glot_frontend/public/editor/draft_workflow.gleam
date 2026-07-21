import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_frontend/public/editor/command
import glot_frontend/public/editor/document
import glot_frontend/public/editor/draft as editor_draft
import glot_frontend/public/editor/draft_policy
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{type Msg}
import glot_frontend/public/editor/model.{
  type RealModel, CustomRunInstructions, DefaultRunInstructions, RealModel,
}
import glot_frontend/public/editor/run_instructions

pub fn apply_loaded_draft(
  model: RealModel,
  slug: String,
  updated_at: Timestamp,
  stored: option.Option(editor_draft.StoredEditorDraft),
) -> #(RealModel, command.Command(Msg)) {
  case model.slug, model.updated_at {
    option.Some(current_slug), option.Some(current_updated_at)
      if current_slug == slug && current_updated_at == updated_at
    ->
      case stored {
        option.Some(stored) ->
          case
            draft_policy.is_newer_than_saved_snippet(
              stored.saved_at_ms,
              updated_at,
            )
          {
            True -> #(
              RealModel(..model, pending_restore_draft: option.Some(stored)),
              command.OpenDialogNextFrame(ids.restore_draft_dialog),
            )
            False -> #(model, command.ClearExistingDraft(slug))
          }
        option.None -> #(model, command.none())
      }
    _, _ -> #(model, command.none())
  }
}

pub fn apply_editor_draft(
  model: RealModel,
  draft: editor_draft.EditorDraft,
) -> RealModel {
  let files = draft.files
  let stdin = draft.stdin
  let selected_tab = document.initial_tab(files, stdin)
  let run_instructions_override = draft.run_instructions_override
  let run_instructions = case run_instructions_override {
    option.Some(instructions) -> instructions
    option.None ->
      run_instructions.default_run_instructions(draft.language, files)
  }

  RealModel(
    ..model,
    title: draft.title,
    title_draft: draft.title,
    language: draft.language,
    files: files,
    stdin: stdin,
    editor_external_revision: model.editor_external_revision + 1,
    selected_tab: selected_tab,
    add_entry_kind: document.default_add_entry_kind(stdin),
    edit_entry_filename: document.default_file_name(files, selected_tab),
    run_instructions_override: run_instructions_override,
    run_instructions_mode_draft: case run_instructions_override {
      option.Some(_) -> CustomRunInstructions
      option.None -> DefaultRunInstructions
    },
    run_instructions_draft: run_instructions.run_instructions_to_draft(
      run_instructions,
    ),
    pending_restore_draft: option.None,
  )
}
