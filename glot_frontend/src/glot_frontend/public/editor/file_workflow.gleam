import gleam/list
import gleam/option
import gleam/string
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/document
import glot_frontend/public/editor/files as editor_files
import glot_frontend/public/editor/model.{
  type RealModel, AddFileEntry, AddStdinEntry, FileTab, RealModel, StdinTab,
}

pub fn reset_add_entry_draft(model: RealModel) -> RealModel {
  RealModel(
    ..model,
    add_entry_kind: document.default_add_entry_kind(model.stdin),
    add_entry_filename: "",
  )
}

pub fn reset_edit_entry_draft(model: RealModel) -> RealModel {
  RealModel(
    ..model,
    edit_entry_filename: document.default_file_name(
      model.files,
      model.selected_tab,
    ),
  )
}

pub fn add_entry(model: RealModel) -> option.Option(RealModel) {
  case model.add_entry_kind {
    AddFileEntry -> add_file_entry(model)
    AddStdinEntry -> add_stdin_entry(model)
  }
}

pub fn add_file_entry(model: RealModel) -> option.Option(RealModel) {
  let filename = string.trim(model.add_entry_filename)
  case
    !editor_files.valid_name(filename)
    || editor_files.name_exists(model.files, filename)
  {
    True -> option.None
    False -> {
      let next_index = list.length(model.files)
      let next_file = snippet_model.File(name: filename, content: "")
      option.Some(
        RealModel(
          ..model,
          files: list.append(model.files, [next_file]),
          selected_tab: FileTab(next_index),
          add_entry_filename: "",
          editor_external_revision: model.editor_external_revision + 1,
        ),
      )
    }
  }
}

pub fn add_stdin_entry(model: RealModel) -> option.Option(RealModel) {
  case model.stdin {
    option.Some(_) -> option.None
    option.None ->
      option.Some(
        RealModel(
          ..model,
          stdin: option.Some(""),
          selected_tab: StdinTab,
          add_entry_filename: "",
          editor_external_revision: model.editor_external_revision + 1,
        ),
      )
  }
}

pub fn rename_selected_file(model: RealModel) -> option.Option(RealModel) {
  case model.selected_tab {
    StdinTab -> option.None
    FileTab(index) -> {
      let filename = string.trim(model.edit_entry_filename)
      case
        !editor_files.valid_name(filename)
        || editor_files.name_exists_except(model.files, filename, index)
      {
        True -> option.None
        False ->
          option.Some(
            RealModel(
              ..model,
              files: editor_files.rename_at(model.files, index, filename),
            ),
          )
      }
    }
  }
}

pub fn delete_selected_entry(model: RealModel) -> option.Option(RealModel) {
  case model.selected_tab {
    StdinTab ->
      option.Some(
        RealModel(
          ..model,
          stdin: option.None,
          selected_tab: FileTab(0),
          edit_entry_filename: document.default_file_name(
            model.files,
            FileTab(0),
          ),
          editor_external_revision: model.editor_external_revision + 1,
        ),
      )

    FileTab(index) ->
      case list.length(model.files) > 1 {
        False -> option.None
        True -> {
          let next_files = editor_files.remove_at(model.files, index)
          let next_tab = case index >= list.length(next_files) {
            True -> FileTab(list.length(next_files) - 1)
            False -> FileTab(index)
          }

          option.Some(
            RealModel(
              ..model,
              files: next_files,
              selected_tab: next_tab,
              edit_entry_filename: document.default_file_name(
                next_files,
                next_tab,
              ),
              editor_external_revision: model.editor_external_revision + 1,
            ),
          )
        }
      }
  }
}

pub fn update_selected_tab_content(
  model: RealModel,
  content: String,
) -> RealModel {
  case model.selected_tab {
    FileTab(index) ->
      RealModel(
        ..model,
        files: editor_files.update_content_at(model.files, index, content),
      )
    StdinTab -> RealModel(..model, stdin: option.Some(content))
  }
}
