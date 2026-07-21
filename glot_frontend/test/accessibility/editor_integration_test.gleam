import gleam/list
import gleam/option
import gleam/time/timestamp
import glot_core/language
import glot_core/run
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/execution
import glot_frontend/public/editor/model
import glot_frontend/public/editor/settings
import glot_frontend/public/editor/view
import glot_frontend/ui/delayed_loading
import lustre/element
import support/accessibility
import support/editor_fixture
import support/editor_scenario

pub fn editor_lifecycle_states_satisfy_the_markup_accessibility_contract_test() {
  let supported = editor_scenario_model()
  let assert model.SupportedLanguage(editor) = supported
  let #(loading, generation) = delayed_loading.begin(delayed_loading.idle())
  let visible_loading = delayed_loading.reveal(loading, generation)
  let completed =
    model.SupportedLanguage(
      model.RealModel(
        ..editor,
        run_state: execution.Completed(
          Ok(run.SuccessfulRun(
            duration: 1,
            stdout: "output",
            stderr: "warning",
            error: "",
          )),
        ),
      ),
    )
  let saving =
    model.SupportedLanguage(
      model.RealModel(..editor, save_state: execution.Saving),
    )
  let save_error =
    model.SupportedLanguage(
      model.RealModel(..editor, save_state: execution.SaveError("Save failed.")),
    )

  [
    model.Initializing(model.NewEditor("javascript")),
    model.LoadingSnippet("fixture", settings.defaults(), visible_loading),
    model.LoadError("Could not load snippet."),
    model.UnsupportedLanguage("fixture"),
    supported,
    model.SupportedLanguage(
      model.RealModel(..editor, run_state: execution.Running),
    ),
    completed,
    model.SupportedLanguage(
      model.RealModel(
        ..editor,
        run_state: execution.Completed(Error(run.FailedRun("Run failed."))),
      ),
    ),
    model.SupportedLanguage(
      model.RealModel(
        ..editor,
        run_state: execution.RequestError("Request failed."),
      ),
    ),
    saving,
    save_error,
  ]
  |> list.each(assert_accessible)
}

pub fn populated_editor_dialogs_satisfy_the_markup_accessibility_contract_test() {
  let assert model.SupportedLanguage(base) = editor_scenario_model()
  let stored =
    editor_fixture.stored_draft(
      saved_at_ms: 300_000,
      title: "Recovered",
      files: [snippet_model.File("main.js", "recovered")],
      stdin: option.Some("input"),
      run_instructions: option.Some(language.RunInstructions([], "node main.js")),
    )
  let populated =
    model.SupportedLanguage(
      model.RealModel(
        ..base,
        slug: option.Some("accessible-editor"),
        owner_user_id: option.Some(editor_fixture.owner_id()),
        owner_username: option.Some("fixture-owner"),
        created_at: option.Some(timestamp.from_unix_seconds(100)),
        updated_at: option.Some(timestamp.from_unix_seconds(200)),
        stdin: option.Some("input"),
        selected_tab: model.StdinTab,
        pending_restore_draft: option.Some(stored),
        add_entry_kind: model.AddFileEntry,
        add_entry_filename: "extra.js",
        run_instructions_mode_draft: model.CustomRunInstructions,
        run_instructions_draft: model.RunInstructionsDraft(
          "npm run build",
          "node main.js",
        ),
      ),
    )
  assert_accessible(populated)
}

fn editor_scenario_model() -> model.Model {
  editor_scenario.new_editor(language.JavaScript)
}

fn assert_accessible(editor_model: model.Model) {
  let document =
    view.view(
      editor_model,
      option.Some(editor_fixture.owner_id()),
      timestamp.from_unix_seconds(300),
    )
    |> element.to_document_string
  assert accessibility.audit_fragment(document) == []
}
