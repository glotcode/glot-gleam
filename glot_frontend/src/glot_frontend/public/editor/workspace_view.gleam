import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/string
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/execution
import glot_frontend/public/editor/files as editor_files
import glot_frontend/public/editor/message.{
  type Msg, AddEntryClicked, SelectedTabActionClicked, SettingsClicked,
  TabKeyPressed, TabSelected,
}
import glot_frontend/public/editor/model.{
  type EditorTab, type RealModel, type RunInstructionsMode, AddFileEntry,
  AddStdinEntry, CustomRunInstructions, DefaultRunInstructions, FileTab,
  StdinTab,
}
import glot_frontend/public/editor/tab_semantics
import glot_web/page/editor_layout
import glot_web/page/icons
import lustre/attribute
import lustre/element.{type Element}
import lustre/event

fn icon_action_button(
  class_name: String,
  aria_label: String,
  msg: Msg,
  children: List(Element(Msg)),
) -> Element(Msg) {
  editor_layout.shell_button(
    class_name: class_name,
    attributes: [
      attribute.attribute("aria-label", aria_label),
      event.on_click(msg),
    ],
    children: children,
  )
}

pub fn tabbar_children(model: RealModel) -> List(Element(Msg)) {
  [
    icon_action_button(
      "editor-shell__settings-button",
      "Editor settings",
      SettingsClicked,
      [icons.cog_6_tooth()],
    ),
    editor_layout.tab_scroll(tab_views(model)),
    selected_tab_action_button(model),
    icon_action_button(
      "editor-shell__tab-action-button",
      "Add editor entry",
      AddEntryClicked,
      [icons.document_plus()],
    ),
  ]
}

pub fn tab_views(model: RealModel) -> List(Element(Msg)) {
  let file_tabs = file_tab_views(model.files, model.selected_tab, 0)
  case model.stdin {
    option.Some(_) ->
      list.append(file_tabs, [
        tab_button("<stdin>", StdinTab, model.selected_tab == StdinTab),
      ])

    option.None -> file_tabs
  }
}

pub fn file_tab_views(
  files: List(snippet_model.File),
  selected_tab: EditorTab,
  index: Int,
) -> List(Element(Msg)) {
  case files {
    [] -> []
    [snippet_model.File(name:, ..), ..rest] -> [
      tab_button(
        tab_label(name),
        FileTab(index),
        selected_tab == FileTab(index),
      ),
      ..file_tab_views(rest, selected_tab, index + 1)
    ]
  }
}

pub fn tab_button(
  label: String,
  tab: EditorTab,
  is_selected: Bool,
) -> Element(Msg) {
  editor_layout.tab_button(
    label: label,
    is_selected: is_selected,
    id: tab_semantics.tab_id(tab),
    panel_id: tab_semantics.panel_id,
    attributes: [
      event.on_click(TabSelected(tab)),
      event.advanced("keydown", {
        use key <- decode.field("key", decode.string)
        let handled =
          key == "Home"
          || key == "End"
          || key == "ArrowRight"
          || key == "ArrowDown"
          || key == "ArrowLeft"
          || key == "ArrowUp"
        decode.success(event.handler(
          TabKeyPressed(tab, key),
          prevent_default: handled,
          stop_propagation: False,
        ))
      }),
    ],
  )
}

pub fn selected_tab_action_button(model: RealModel) -> Element(Msg) {
  editor_layout.tab_meta_button(
    aria_label: selected_tab_action_label(model.selected_tab),
    pill_label: "Edit",
    attributes: [event.on_click(SelectedTabActionClicked)],
  )
}

pub fn run_button_text(run_state: execution.RunState) -> String {
  case run_state {
    execution.Running -> "Running..."
    _ -> "Run"
  }
}

pub fn save_button_text(save_state: execution.SaveState) -> String {
  case save_state {
    execution.Saving -> "Saving..."
    _ -> "Save"
  }
}

pub fn run_instructions_mode_to_string(mode: RunInstructionsMode) -> String {
  case mode {
    DefaultRunInstructions -> "default"
    CustomRunInstructions -> "custom"
  }
}

pub fn can_submit_add_entry(model: RealModel) -> Bool {
  case model.add_entry_kind {
    AddFileEntry -> {
      let filename = string.trim(model.add_entry_filename)
      editor_files.valid_name(filename)
      && !editor_files.name_exists(model.files, filename)
    }

    AddStdinEntry ->
      case model.stdin {
        option.Some(_) -> False
        option.None -> True
      }
  }
}

pub fn add_stdin_message(stdin: option.Option(String)) -> String {
  case stdin {
    option.Some(_) -> "<stdin> already exists for this snippet."
    option.None -> "Add a dedicated <stdin> tab for runtime input."
  }
}

pub fn can_submit_edit_entry(model: RealModel) -> Bool {
  case model.selected_tab {
    StdinTab -> False
    FileTab(index) -> {
      let filename = string.trim(model.edit_entry_filename)
      editor_files.valid_name(filename)
      && !editor_files.name_exists_except(model.files, filename, index)
    }
  }
}

pub fn can_delete_selected_file(model: RealModel) -> Bool {
  case model.selected_tab {
    FileTab(_) -> list.length(model.files) > 1
    StdinTab -> False
  }
}

pub fn tab_label(filename: String) -> String {
  case string.length(filename) > 10 {
    False -> filename
    True -> editor_files.truncated_name(filename)
  }
}

pub fn selected_tab_content(model: RealModel) -> String {
  case model.selected_tab {
    FileTab(index) -> editor_files.content_at(model.files, index)
    StdinTab ->
      case model.stdin {
        option.Some(content) -> content
        option.None -> ""
      }
  }
}

pub fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

pub fn selected_tab_action_label(tab: EditorTab) -> String {
  case tab {
    FileTab(_) -> "Edit selected file"
    StdinTab -> "Manage stdin tab"
  }
}
