import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/language
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/command
import glot_frontend/public/editor/document
import glot_frontend/public/editor/execution
import glot_frontend/public/editor/message.{type Msg, ExistingDraftLoaded}
import glot_frontend/public/editor/model.{
  type Model, CustomRunInstructions, DefaultRunInstructions, RealModel,
  SupportedLanguage,
}
import glot_frontend/public/editor/run_instructions
import glot_frontend/public/editor/settings as editor_settings
import youid/uuid.{type Uuid}

pub fn existing_model_from_response(
  response: snippet_dto.SnippetResponse,
  settings: editor_settings.EditorSettings,
) -> #(Model, command.Command(Msg)) {
  existing_model_from_data(
    slug: response.slug,
    owner_user_id: option.Some(response.user.id),
    owner_username: option.Some(response.user.username),
    title: title_or_default(response.data.title),
    language: response.data.language,
    visibility: response.data.visibility,
    created_at: option.Some(response.created_at),
    updated_at: response.updated_at,
    run_instructions_override: response.data.run_instructions,
    files: response.data.files,
    stdin: stdin_option(response.data.stdin),
    settings: settings,
  )
}

pub fn existing_model_from_data(
  slug slug: String,
  owner_user_id owner_user_id: option.Option(Uuid),
  owner_username owner_username: option.Option(String),
  title title: String,
  language language: language.Language,
  visibility visibility: snippet_model.Visibility,
  created_at created_at: option.Option(Timestamp),
  updated_at updated_at: Timestamp,
  run_instructions_override run_instructions_override: option.Option(
    language.RunInstructions,
  ),
  files files: List(snippet_model.File),
  stdin stdin: option.Option(String),
  settings settings: editor_settings.EditorSettings,
) -> #(Model, command.Command(Msg)) {
  let run_instructions_mode_draft = case run_instructions_override {
    option.Some(_) -> CustomRunInstructions
    option.None -> DefaultRunInstructions
  }
  let run_instructions_draft = case run_instructions_override {
    option.Some(run_instructions) ->
      run_instructions.run_instructions_to_draft(run_instructions)
    option.None ->
      run_instructions.run_instructions_to_draft(
        run_instructions.default_run_instructions(language, files),
      )
  }
  let selected_tab = document.initial_tab(files, stdin)
  let next_model =
    SupportedLanguage(RealModel(
      slug: option.Some(slug),
      owner_user_id: owner_user_id,
      owner_username: owner_username,
      title: title,
      title_draft: title,
      language: language,
      visibility: visibility,
      created_at: created_at,
      updated_at: option.Some(updated_at),
      files: files,
      stdin: stdin,
      editor_revision: 0,
      editor_external_revision: 0,
      selected_tab: selected_tab,
      add_entry_kind: document.default_add_entry_kind(stdin),
      add_entry_filename: "",
      edit_entry_filename: document.default_file_name(files, selected_tab),
      editor_settings: settings,
      editor_settings_draft: settings,
      run_instructions_override: run_instructions_override,
      run_instructions_mode_draft: run_instructions_mode_draft,
      run_instructions_draft: run_instructions_draft,
      save_visibility_draft: visibility,
      pending_restore_draft: option.None,
      version_info: option.None,
      run_generation: 0,
      run_state: execution.Idle,
      save_generation: 0,
      save_state: execution.SaveIdle,
    ))

  #(
    next_model,
    command.batch([
      run_instructions.version_run_command(language),
      command.LoadExistingDraft(slug, fn(stored) {
        ExistingDraftLoaded(slug, updated_at, stored)
      }),
    ]),
  )
}

pub fn title_or_default(title: String) -> String {
  case title == "" {
    True -> "Hello World"
    False -> title
  }
}

pub fn stdin_option(stdin: String) -> option.Option(String) {
  case stdin == "" {
    True -> option.None
    False -> option.Some(stdin)
  }
}
