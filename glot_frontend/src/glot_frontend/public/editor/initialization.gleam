import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/language
import glot_core/run
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/command
import glot_frontend/public/editor/document
import glot_frontend/public/editor/execution
import glot_frontend/public/editor/files as editor_files
import glot_frontend/public/editor/message.{
  type Msg, EnvironmentLoaded, ExistingDraftLoaded, NewDraftLoaded,
  SnippetLoaded, SnippetLoadingDelayElapsed, VersionRunFinished,
}
import glot_frontend/public/editor/model.{
  type InitTarget, type Model, type RealModel, type RunInstructionsDraft,
  AddFileEntry, CustomRunInstructions, DefaultRunInstructions, ExistingEditor,
  FileTab, Initializing, LoadError, LoadingSnippet, NewEditor, RealModel,
  RunInstructionsDraft, SupportedLanguage, UnsupportedLanguage,
}
import glot_frontend/public/editor/settings
import glot_frontend/ui/delayed_loading
import glot_web/page/editor as editor_ssr
import youid/uuid.{type Uuid}

pub fn start(target: InitTarget) -> #(Model, command.Command(Msg)) {
  #(
    Initializing(target),
    command.LoadEnvironment(fn(raw_ssr, settings) {
      EnvironmentLoaded(target, raw_ssr, settings)
    }),
  )
}

/// Handle initialization messages, returning `None` once the regular editor
/// reducer owns the model and message.
pub fn update(
  model: Model,
  msg: Msg,
) -> option.Option(#(Model, command.Command(Msg))) {
  case model, msg {
    Initializing(current_target),
      EnvironmentLoaded(target, raw_ssr, editor_settings)
      if current_target == target
    ->
      option.Some(case target {
        NewEditor(language_slug) ->
          init_new_after_environment(
            language_slug,
            parse_ssr_view_model(raw_ssr),
            editor_settings,
          )
        ExistingEditor(slug) ->
          init_existing_after_ssr(
            slug,
            parse_ssr_view_model(raw_ssr),
            editor_settings,
          )
      })
    Initializing(_), _ -> option.Some(#(model, command.none()))
    _, EnvironmentLoaded(_, _, _) -> option.Some(#(model, command.none()))
    _, _ -> option.None
  }
}

fn init_existing_after_environment(
  slug: String,
  editor_settings: settings.EditorSettings,
) -> #(Model, command.Command(Msg)) {
  let #(loading_indicator, generation) =
    delayed_loading.begin(delayed_loading.idle())
  #(
    LoadingSnippet(slug, editor_settings, loading_indicator),
    command.batch([
      command.GetSnippet(snippet_dto.GetSnippetRequest(slug: slug), fn(result) {
        SnippetLoaded(slug, result)
      }),
      command.Schedule(
        delayed_loading.delay(),
        SnippetLoadingDelayElapsed(slug, generation),
      ),
    ]),
  )
}

fn init_new_after_environment(
  language_slug: String,
  ssr_model: option.Option(editor_ssr.ViewModel),
  editor_settings: settings.EditorSettings,
) -> #(Model, command.Command(Msg)) {
  case ssr_model {
    option.Some(editor_ssr.NewSnippet(editor_ssr.EditorModel(language:, ..))) ->
      init_supported_new(language, editor_settings)
    option.Some(editor_ssr.UnsupportedLanguage(language_slug)) -> #(
      UnsupportedLanguage(language_slug),
      command.none(),
    )
    option.Some(editor_ssr.LoadError(message)) -> #(
      LoadError(message),
      command.none(),
    )
    option.Some(editor_ssr.ExistingSnippet(_)) | option.None ->
      case language.from_string(language_slug) {
        option.Some(language) -> init_supported_new(language, editor_settings)
        option.None -> #(UnsupportedLanguage(language_slug), command.none())
      }
  }
}

fn init_existing_after_ssr(
  slug: String,
  ssr_model: option.Option(editor_ssr.ViewModel),
  editor_settings: settings.EditorSettings,
) -> #(Model, command.Command(Msg)) {
  case ssr_model {
    option.Some(editor_ssr.ExistingSnippet(ssr_model)) ->
      existing_model_from_ssr(ssr_model, editor_settings)
    option.Some(editor_ssr.LoadError(message)) -> #(
      LoadError(message),
      command.none(),
    )
    option.Some(editor_ssr.NewSnippet(_))
    | option.Some(editor_ssr.UnsupportedLanguage(_))
    | option.None -> init_existing_after_environment(slug, editor_settings)
  }
}

fn parse_ssr_view_model(raw: String) -> option.Option(editor_ssr.ViewModel) {
  case raw {
    "" -> option.None
    raw ->
      case json.parse(raw, editor_ssr.decoder()) {
        Ok(view_model) -> option.Some(view_model)
        Error(_) -> option.None
      }
  }
}

fn existing_model_from_ssr(
  ssr_model: editor_ssr.EditorModel,
  editor_settings: settings.EditorSettings,
) -> #(Model, command.Command(Msg)) {
  let editor_ssr.EditorModel(
    slug: slug,
    owner_user_id: owner_user_id,
    owner_username: owner_username,
    title: title,
    language: language,
    visibility: visibility,
    created_at: created_at,
    updated_at: updated_at,
    run_instructions_override: run_instructions_override,
    files: files,
    stdin: stdin,
  ) = ssr_model

  case slug, visibility, updated_at {
    option.Some(slug), option.Some(visibility), option.Some(updated_at) ->
      existing_model_from_data(
        slug: slug,
        owner_user_id: owner_user_id,
        owner_username: owner_username,
        title: title,
        language: language,
        visibility: visibility,
        created_at: created_at,
        updated_at: updated_at,
        run_instructions_override: run_instructions_override,
        files: files,
        stdin: stdin,
        editor_settings: editor_settings,
      )
    _, _, _ -> #(LoadError("Could not load snippet."), command.none())
  }
}

fn existing_model_from_data(
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
  editor_settings editor_settings: settings.EditorSettings,
) -> #(Model, command.Command(Msg)) {
  let run_instructions_mode_draft = case run_instructions_override {
    option.Some(_) -> CustomRunInstructions
    option.None -> DefaultRunInstructions
  }
  let run_instructions_draft = case run_instructions_override {
    option.Some(run_instructions) -> run_instructions_to_draft(run_instructions)
    option.None ->
      run_instructions_to_draft(default_run_instructions(language, files))
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
      editor_settings: editor_settings,
      editor_settings_draft: editor_settings,
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
      version_run_command(language),
      command.LoadExistingDraft(slug, fn(stored) {
        ExistingDraftLoaded(slug, updated_at, stored)
      }),
    ]),
  )
}

fn init_supported_new(
  language: language.Language,
  editor_settings: settings.EditorSettings,
) -> #(Model, command.Command(Msg)) {
  let model = SupportedLanguage(new_editor_model(language, editor_settings))
  let language_slug = language.to_string(language)
  #(
    model,
    command.batch([
      version_run_command(language),
      command.LoadNewDraft(language_slug, fn(stored) {
        NewDraftLoaded(language_slug, stored)
      }),
    ]),
  )
}

fn new_editor_model(
  lang: language.Language,
  editor_settings: settings.EditorSettings,
) -> RealModel {
  let default_file = snippet_model.default_file(lang)
  RealModel(
    slug: option.None,
    owner_user_id: option.None,
    owner_username: option.None,
    title: "Hello World",
    title_draft: "Hello World",
    language: lang,
    visibility: snippet_model.Unlisted,
    created_at: option.None,
    updated_at: option.None,
    files: [default_file],
    stdin: option.None,
    editor_revision: 0,
    editor_external_revision: 0,
    selected_tab: FileTab(0),
    add_entry_kind: AddFileEntry,
    add_entry_filename: "",
    edit_entry_filename: document.default_file_name([default_file], FileTab(0)),
    editor_settings: editor_settings,
    editor_settings_draft: editor_settings,
    run_instructions_override: option.None,
    run_instructions_mode_draft: DefaultRunInstructions,
    run_instructions_draft: run_instructions_to_draft(
      default_run_instructions(lang, [default_file]),
    ),
    save_visibility_draft: snippet_model.Unlisted,
    pending_restore_draft: option.None,
    version_info: option.None,
    run_generation: 0,
    run_state: execution.Idle,
    save_generation: 0,
    save_state: execution.SaveIdle,
  )
}

fn run_instructions_to_draft(
  run_instructions: language.RunInstructions,
) -> RunInstructionsDraft {
  RunInstructionsDraft(
    build_commands_text: string.join(
      run_instructions.build_commands,
      with: "\n",
    ),
    run_command: run_instructions.run_command,
  )
}

fn default_run_instructions(
  lang: language.Language,
  files: List(snippet_model.File),
) -> language.RunInstructions {
  let default_name = language.default_filename(lang)
  let main_file = editor_files.select_main_name(files, default_name)
  let other_files =
    files
    |> list.map(fn(file) { file.name })
    |> editor_files.remove_first_name(main_file)
  language.run_instructions(lang, main_file, other_files)
}

fn version_run_command(lang: language.Language) -> command.Command(Msg) {
  command.GetLanguageVersion(
    run.GetLanguageVersionRequest(language: lang),
    fn(result) { VersionRunFinished(lang, result) },
  )
}
