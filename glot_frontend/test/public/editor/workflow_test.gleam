import gleam/option
import gleeunit
import glot_core/language
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/file_workflow
import glot_frontend/public/editor/model
import glot_frontend/public/editor/run_instructions
import support/editor_scenario

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn custom_run_instructions_are_normalized_from_the_draft_test() {
  let instructions =
    model.RunInstructionsDraft(
      build_commands_text: " npm install \n\n npm run build ",
      run_command: " node main.js ",
    )
    |> run_instructions.run_instructions_from_draft

  assert instructions.build_commands == ["npm install", "npm run build"]
  assert instructions.run_command == "node main.js"
}

pub fn file_workflow_adds_selects_and_updates_a_file_atomically_test() {
  let assert model.SupportedLanguage(editor) =
    editor_scenario.new_editor(language.JavaScript)
  let adding =
    model.RealModel(
      ..editor,
      add_entry_kind: model.AddFileEntry,
      add_entry_filename: " helper.js ",
    )
  let assert option.Some(added) = file_workflow.add_entry(adding)
  assert added.selected_tab == model.FileTab(1)
  assert added.files
    == [
      snippet_model.File("main.js", "console.log(\"Hello World!\");"),
      snippet_model.File("helper.js", ""),
    ]

  let updated = file_workflow.update_selected_tab_content(added, "export {}")
  assert updated.files
    == [
      snippet_model.File("main.js", "console.log(\"Hello World!\");"),
      snippet_model.File("helper.js", "export {}"),
    ]
}

pub fn deleting_the_only_file_is_rejected_test() {
  let assert model.SupportedLanguage(editor) =
    editor_scenario.new_editor(language.JavaScript)
  assert file_workflow.delete_selected_entry(editor) == option.None
}
