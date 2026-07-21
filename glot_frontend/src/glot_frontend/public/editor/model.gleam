import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/language
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/draft
import glot_frontend/public/editor/execution
import glot_frontend/public/editor/settings
import glot_frontend/ui/delayed_loading
import youid/uuid.{type Uuid}

pub type Model {
  Initializing(InitTarget)
  UnsupportedLanguage(String)
  LoadingSnippet(String, settings.EditorSettings, delayed_loading.State)
  LoadError(String)
  SupportedLanguage(RealModel)
}

pub type InitTarget {
  NewEditor(String)
  ExistingEditor(String)
}

pub type RealModel {
  RealModel(
    slug: option.Option(String),
    owner_user_id: option.Option(Uuid),
    owner_username: option.Option(String),
    title: String,
    title_draft: String,
    language: language.Language,
    visibility: snippet_model.Visibility,
    created_at: option.Option(Timestamp),
    updated_at: option.Option(Timestamp),
    files: List(snippet_model.File),
    stdin: option.Option(String),
    editor_revision: Int,
    editor_external_revision: Int,
    selected_tab: EditorTab,
    add_entry_kind: AddEntryKind,
    add_entry_filename: String,
    edit_entry_filename: String,
    editor_settings: settings.EditorSettings,
    editor_settings_draft: settings.EditorSettings,
    run_instructions_override: option.Option(language.RunInstructions),
    run_instructions_mode_draft: RunInstructionsMode,
    run_instructions_draft: RunInstructionsDraft,
    save_visibility_draft: snippet_model.Visibility,
    pending_restore_draft: option.Option(draft.StoredEditorDraft),
    version_info: option.Option(String),
    run_generation: Int,
    run_state: execution.RunState,
    save_generation: Int,
    save_state: execution.SaveState,
  )
}

pub type RunInstructionsDraft {
  RunInstructionsDraft(build_commands_text: String, run_command: String)
}

pub type RunInstructionsMode {
  DefaultRunInstructions
  CustomRunInstructions
}

pub type EditorTab {
  FileTab(Int)
  StdinTab
}

pub type AddEntryKind {
  AddFileEntry
  AddStdinEntry
}
