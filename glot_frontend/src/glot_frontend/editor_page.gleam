import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_core/api_action
import glot_core/helpers/timestamp_helpers
import glot_core/language
import glot_core/run
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_frontend/app_dialog
import glot_frontend/api
import glot_frontend/editor_draft
import glot_frontend/editor_settings
import glot_frontend/icons
import glot_frontend/route
import glot_frontend/string_helpers
import glot_frontend/top_bar
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import youid/uuid.{type Uuid}

const title_dialog_id = "editor-page-title-dialog"

const add_entry_dialog_id = "editor-page-add-entry-dialog"

const edit_entry_dialog_id = "editor-page-edit-entry-dialog"

const settings_dialog_id = "editor-page-settings-dialog"

const save_dialog_id = "editor-page-save-dialog"

const snippet_info_dialog_id = "editor-page-snippet-info-dialog"

const restore_draft_dialog_id = "editor-page-restore-draft-dialog"

const editor_id = "editor-page-codemirror"

pub type Model {
  UnsupportedLanguage(String)
  LoadingSnippet(String, editor_settings.EditorSettings)
  LoadError(String)
  SupportedLanguage(RealModel)
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
    selected_tab: EditorTab,
    add_entry_kind: AddEntryKind,
    add_entry_filename: String,
    edit_entry_filename: String,
    editor_settings: editor_settings.EditorSettings,
    editor_settings_draft: editor_settings.EditorSettings,
    run_instructions_override: option.Option(language.RunInstructions),
    run_instructions_mode_draft: RunInstructionsMode,
    run_instructions_draft: RunInstructionsDraft,
    save_visibility_draft: snippet_model.Visibility,
    pending_restore_draft: option.Option(editor_draft.StoredEditorDraft),
    version_info: option.Option(String),
    run_state: RunState,
    save_state: SaveState,
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

pub type RunState {
  Idle
  Running
  Completed(run.RunResult)
  RequestError(String)
}

pub type SaveState {
  SaveIdle
  Saving
  Saved(slug: String)
  SaveError(String)
}

type SaveOperation {
  CreateSnippet
  UpdateSnippet(String)
}

pub fn init_new(language: String) -> #(Model, Effect(Msg)) {
  let settings = editor_settings.load()
  let model = case language.from_string(language) {
    option.Some(lang) -> {
      let draft = editor_draft.load_new_snippet(language)
      SupportedLanguage(new_editor_model(lang, settings, draft))
    }

    option.None -> UnsupportedLanguage(language)
  }

  #(model, init_new_effect_for_model(model))
}

pub fn init_existing(slug: String) -> #(Model, Effect(Msg)) {
  let settings = editor_settings.load()
  #(
    LoadingSnippet(slug, settings),
    api.get_snippet(snippet_dto.GetSnippetRequest(slug: slug), SnippetLoaded),
  )
}

pub type Msg {
  SnippetLoaded(api.ApiResponse(snippet_dto.SnippetResponse))
  TitleClicked
  TitleDraftChanged(String)
  TitleEditCancelled
  TitleEditSubmitted
  TitleDialogClosed
  AddEntryClicked
  AddEntryKindSelected(AddEntryKind)
  AddEntryFilenameChanged(String)
  AddEntryCancelled
  AddEntrySubmitted
  AddEntryDialogClosed
  SelectedTabActionClicked
  EditEntryFilenameChanged(String)
  EditEntryCancelled
  EditEntrySubmitted
  EditEntryDeleted
  EditEntryDialogClosed
  SettingsClicked
  KeyboardBindingsDraftSelected(editor_settings.KeyboardBindings)
  RunInstructionsModeDraftChanged(String)
  RunInstructionsBuildCommandsDraftChanged(String)
  RunInstructionsRunCommandDraftChanged(String)
  SettingsCancelled
  SettingsSubmitted
  SettingsDialogClosed
  SaveClicked
  SaveVisibilityDraftSelected(snippet_model.Visibility)
  SaveCancelled
  SaveConfirmed
  SaveDialogClosed
  RestoreDraftAccepted
  RestoreDraftDeclined
  RestoreDraftClosed
  SnippetInfoClicked
  SnippetInfoDismissed
  SnippetInfoClosed
  TabSelected(EditorTab)
  SourceCodeChanged(String)
  RunSubmitted
  RunFinished(api.ApiResponse(run.RunResult))
  VersionRunFinished(api.ApiResponse(run.RunResult))
  SaveFinished(api.ApiResponse(snippet_dto.SnippetResponse))
}

pub fn update(
  model: Model,
  msg: Msg,
  current_user_id: option.Option(Uuid),
) -> #(Model, Effect(Msg)) {
  case model, msg {
    LoadingSnippet(_, settings), SnippetLoaded(result) -> {
      case result {
        api.ApiSuccess(response) -> {
          let files = response.data.files
          let stdin = stdin_option(response.data.stdin)
          let run_instructions_override = response.data.run_instructions
          let run_instructions_mode_draft = case run_instructions_override {
            option.Some(_) -> CustomRunInstructions
            option.None -> DefaultRunInstructions
          }
          let run_instructions_draft = case run_instructions_override {
            option.Some(run_instructions) ->
              run_instructions_to_draft(run_instructions)
            option.None ->
              run_instructions_to_draft(default_run_instructions(
                response.data.language,
                files,
              ))
          }

          let #(pending_restore_draft, draft_effect) =
            load_existing_restore_draft(response.slug, response.updated_at)

          let next_model =
            SupportedLanguage(RealModel(
              slug: option.Some(response.slug),
              owner_user_id: option.Some(response.user.id),
              owner_username: option.Some(response.user.username),
              title: title_or_default(response.data.title),
              title_draft: title_or_default(response.data.title),
              language: response.data.language,
              visibility: response.data.visibility,
              created_at: option.Some(response.created_at),
              updated_at: option.Some(response.updated_at),
              files: files,
              stdin: stdin,
              selected_tab: initial_selected_tab(files, stdin),
              add_entry_kind: default_add_entry_kind(stdin),
              add_entry_filename: "",
              edit_entry_filename: default_file_name(
                files,
                initial_selected_tab(files, stdin),
              ),
              editor_settings: settings,
              editor_settings_draft: settings,
              run_instructions_override: run_instructions_override,
              run_instructions_mode_draft: run_instructions_mode_draft,
              run_instructions_draft: run_instructions_draft,
              save_visibility_draft: response.data.visibility,
              pending_restore_draft: pending_restore_draft,
              version_info: option.None,
              run_state: Idle,
              save_state: SaveIdle,
            ))

          #(
            next_model,
            effect.batch([
              version_run_effect(response.data.language),
              draft_effect,
              restore_draft_effect(next_model),
            ]),
          )
        }

        api.ApiFailure(error) -> #(LoadError(error.message), effect.none())

        api.HttpFailure(_) -> #(
          LoadError("Could not load snippet."),
          effect.none(),
        )
      }
    }

    UnsupportedLanguage(_), _ -> #(model, effect.none())
    LoadingSnippet(_, _), _ -> #(model, effect.none())
    LoadError(_), _ -> #(model, effect.none())
    SupportedLanguage(model), _ ->
      update_helper(model, msg, current_user_id)
      |> pair.map_first(SupportedLanguage)
  }
}

pub fn update_helper(
  model: RealModel,
  msg: Msg,
  current_user_id: option.Option(Uuid),
) -> #(RealModel, Effect(Msg)) {
  case msg {
    SnippetLoaded(_) -> #(model, effect.none())

    TitleClicked -> #(
      RealModel(..model, title_draft: model.title),
      app_dialog.open(title_dialog_id),
    )

    TitleDraftChanged(title_draft) -> #(
      RealModel(..model, title_draft: title_draft),
      effect.none(),
    )

    TitleEditCancelled -> #(
      RealModel(..model, title_draft: model.title),
      app_dialog.close(title_dialog_id),
    )

    TitleEditSubmitted -> {
      let next_model = RealModel(..model, title: model.title_draft)
      #(
        next_model,
        effect.batch([
          app_dialog.close(title_dialog_id),
          save_editor_draft(next_model),
        ]),
      )
    }

    TitleDialogClosed -> #(
      RealModel(..model, title_draft: model.title),
      focus_editor(),
    )

    AddEntryClicked -> #(
      RealModel(
        ..model,
        add_entry_kind: default_add_entry_kind(model.stdin),
        add_entry_filename: "",
      ),
      app_dialog.open(add_entry_dialog_id),
    )

    AddEntryKindSelected(kind) -> #(
      RealModel(..model, add_entry_kind: kind),
      effect.none(),
    )

    AddEntryFilenameChanged(filename) -> #(
      RealModel(..model, add_entry_filename: filename),
      effect.none(),
    )

    AddEntryCancelled -> #(
      reset_add_entry_draft(model),
      app_dialog.close(add_entry_dialog_id),
    )

    AddEntrySubmitted -> {
      case add_entry(model) {
        option.Some(next_model) -> #(
          next_model,
          effect.batch([
            app_dialog.close(add_entry_dialog_id),
            save_editor_draft(next_model),
          ]),
        )

        option.None -> #(model, effect.none())
      }
    }

    AddEntryDialogClosed -> #(
      reset_add_entry_draft(model),
      focus_editor(),
    )

    SelectedTabActionClicked -> #(
      RealModel(
        ..model,
        edit_entry_filename: default_file_name(model.files, model.selected_tab),
      ),
      app_dialog.open(edit_entry_dialog_id),
    )

    EditEntryFilenameChanged(filename) -> #(
      RealModel(..model, edit_entry_filename: filename),
      effect.none(),
    )

    EditEntryCancelled -> #(
      reset_edit_entry_draft(model),
      app_dialog.close(edit_entry_dialog_id),
    )

    EditEntrySubmitted -> {
      case rename_selected_file(model) {
        option.Some(next_model) -> #(
          next_model,
          effect.batch([
            app_dialog.close(edit_entry_dialog_id),
            save_editor_draft(next_model),
          ]),
        )

        option.None -> #(model, effect.none())
      }
    }

    EditEntryDeleted -> {
      case delete_selected_entry(model) {
        option.Some(next_model) -> #(
          next_model,
          effect.batch([
            app_dialog.close(edit_entry_dialog_id),
            save_editor_draft(next_model),
          ]),
        )

        option.None -> #(model, effect.none())
      }
    }

    EditEntryDialogClosed -> #(
      reset_edit_entry_draft(model),
      focus_editor(),
    )

    SettingsClicked -> #(
      RealModel(
        ..model,
        editor_settings_draft: model.editor_settings,
        run_instructions_mode_draft: run_instructions_mode(model),
        run_instructions_draft: run_instructions_to_draft(
          effective_run_instructions(model),
        ),
      ),
      app_dialog.open(settings_dialog_id),
    )

    KeyboardBindingsDraftSelected(bindings) -> #(
      RealModel(
        ..model,
        editor_settings_draft: editor_settings.EditorSettings(
          keyboard_bindings: bindings,
        ),
      ),
      effect.none(),
    )

    RunInstructionsModeDraftChanged(value) -> #(
      RealModel(
        ..model,
        run_instructions_mode_draft: run_instructions_mode_from_string(value),
      ),
      effect.none(),
    )

    RunInstructionsBuildCommandsDraftChanged(build_commands_text) -> {
      #(
        RealModel(
          ..model,
          run_instructions_draft: RunInstructionsDraft(
            build_commands_text: build_commands_text,
            run_command: model.run_instructions_draft.run_command,
          ),
        ),
        effect.none(),
      )
    }

    RunInstructionsRunCommandDraftChanged(run_command) -> {
      #(
        RealModel(
          ..model,
          run_instructions_draft: RunInstructionsDraft(
            build_commands_text: model.run_instructions_draft.build_commands_text,
            run_command: run_command,
          ),
        ),
        effect.none(),
      )
    }

    SettingsCancelled -> #(
      RealModel(
        ..model,
        editor_settings_draft: model.editor_settings,
        run_instructions_mode_draft: run_instructions_mode(model),
        run_instructions_draft: run_instructions_to_draft(
          effective_run_instructions(model),
        ),
      ),
      app_dialog.close(settings_dialog_id),
    )

    SettingsSubmitted -> {
      let next_model =
        RealModel(
          ..model,
          editor_settings: model.editor_settings_draft,
          run_instructions_override: run_instructions_override_from_draft(model),
        )

      #(
        next_model,
        effect.batch([
          app_dialog.close(settings_dialog_id),
          editor_settings.save(model.editor_settings_draft),
          save_editor_draft(next_model),
        ]),
      )
    }

    SettingsDialogClosed -> #(
      RealModel(
        ..model,
        editor_settings_draft: model.editor_settings,
        run_instructions_mode_draft: run_instructions_mode(model),
        run_instructions_draft: run_instructions_to_draft(
          effective_run_instructions(model),
        ),
      ),
      focus_editor(),
    )

    SaveClicked -> #(
      RealModel(..model, save_visibility_draft: model.visibility),
      app_dialog.open(save_dialog_id),
    )

    SaveVisibilityDraftSelected(visibility) -> #(
      RealModel(..model, save_visibility_draft: visibility),
      effect.none(),
    )

    SaveCancelled -> #(
      reset_save_dialog_draft(model),
      app_dialog.close(save_dialog_id),
    )

    SaveDialogClosed -> #(
      reset_save_dialog_draft(model),
      focus_editor(),
    )

    RestoreDraftAccepted -> {
      case model.pending_restore_draft {
        option.Some(draft) -> #(
          apply_editor_draft(model, draft.draft),
          app_dialog.close(restore_draft_dialog_id),
        )

        option.None -> #(model, effect.none())
      }
    }

    RestoreDraftDeclined -> #(
      RealModel(..model, pending_restore_draft: option.None),
      effect.batch([
        app_dialog.close(restore_draft_dialog_id),
        clear_editor_draft(model),
      ]),
    )

    RestoreDraftClosed -> #(
      RealModel(..model, pending_restore_draft: option.None),
      focus_editor(),
    )

    SnippetInfoClicked -> #(model, app_dialog.open(snippet_info_dialog_id))

    SnippetInfoDismissed -> #(model, app_dialog.close(snippet_info_dialog_id))

    SnippetInfoClosed -> #(model, focus_editor())

    TabSelected(tab) -> #(
      RealModel(
        ..model,
        selected_tab: tab,
        edit_entry_filename: default_file_name(model.files, tab),
      ),
      effect.none(),
    )

    SourceCodeChanged(source_code) -> {
      let next_model = update_selected_tab_content(model, source_code)
      #(next_model, save_editor_draft(next_model))
    }

    RunSubmitted -> {
      let request =
        run.RunRequest(
          image: language.container_image(model.language),
          payload: run.RunRequestPayload(
            run_instructions: effective_run_instructions(model),
            files: model.files,
            stdin: model.stdin,
          ),
        )

      #(
        RealModel(..model, run_state: Running),
        api.run_code(request, RunFinished),
      )
    }

    RunFinished(result) -> {
      case result {
        api.ApiSuccess(run_result) -> #(
          RealModel(..model, run_state: Completed(run_result)),
          effect.none(),
        )

        api.ApiFailure(error) -> #(
          RealModel(..model, run_state: RequestError(error.message)),
          effect.none(),
        )

        api.HttpFailure(_) -> #(
          RealModel(
            ..model,
            run_state: RequestError(
              "Could not complete "
              <> api_action.to_string(api_action.RunAction)
              <> ".",
            ),
          ),
          effect.none(),
        )
      }
    }

    VersionRunFinished(result) -> {
      case result {
        api.ApiSuccess(Ok(run.SuccessfulRun(stdout:, ..))) ->
          case stdout == "" {
            True -> #(model, effect.none())
            False -> #(
              RealModel(..model, version_info: option.Some(stdout)),
              effect.none(),
            )
          }

        _ -> #(model, effect.none())
      }
    }

    SaveConfirmed -> {
      let visibility = save_visibility(model, current_user_id)
      let data =
        snippet_dto.SnippetData(
          title: model.title,
          language: model.language,
          visibility: visibility,
          stdin: stdin_to_string(model.stdin),
          run_instructions: model.run_instructions_override,
          files: model.files,
        )

      let save_effect = case save_operation(model, current_user_id) {
        CreateSnippet ->
          api.create_snippet(
            snippet_dto.CreateSnippetRequest(data: data),
            SaveFinished,
          )

        UpdateSnippet(slug) ->
          api.update_snippet(
            snippet_dto.UpdateSnippetRequest(slug: slug, data: data),
            SaveFinished,
          )
      }

      #(
        RealModel(..model, visibility: visibility, save_state: Saving),
        effect.batch([app_dialog.close(save_dialog_id), save_effect]),
      )
    }

    SaveFinished(result) -> {
      case result {
        api.ApiSuccess(response) -> {
          let next_model = RealModel(..model, save_state: Saved(response.slug))
          let clear_draft_effect = clear_editor_draft(next_model)
          case save_operation(model, current_user_id) {
            UpdateSnippet(_) -> #(next_model, clear_draft_effect)
            CreateSnippet -> {
              let navigate =
                modem.push(
                  route.to_string(route.Snippet(response.slug)),
                  option.None,
                  option.None,
                )
              #(next_model, effect.batch([clear_draft_effect, navigate]))
            }
          }
        }

        api.ApiFailure(error) -> #(
          RealModel(..model, save_state: SaveError(error.message)),
          effect.none(),
        )

        api.HttpFailure(_) -> #(
          RealModel(
            ..model,
            save_state: SaveError(
              "Could not complete "
              <> save_action_name(model, current_user_id)
              <> ".",
            ),
          ),
          effect.none(),
        )
      }
    }
  }
}

pub fn view(model: Model, current_user_id: option.Option(Uuid)) -> Element(Msg) {
  case model {
    UnsupportedLanguage(lang) ->
      html.div([], [html.text("Unsupported language: " <> lang)])
    LoadingSnippet(_slug, _settings) ->
      html.div([], [html.text("Loading snippet...")])
    LoadError(message) -> html.div([], [html.text(message)])
    SupportedLanguage(model) -> view_helper(model, current_user_id)
  }
}

fn view_helper(
  model: RealModel,
  current_user_id: option.Option(Uuid),
) -> Element(Msg) {
  let can_edit_title =
    model.slug == option.None || is_owner(model, current_user_id)
  let show_snippet_info = model.slug != option.None

  html.div([attribute.class("editor-page")], [
    html.div([attribute.class("editor-page__screen-glow")], []),
    html.main([attribute.class("editor-shell")], [
      html.div([attribute.class("editor-shell__bezel")], [
        html.div([attribute.class("editor-page__title-row")], [
          html.h1([attribute.class("editor-page__title")], [
            html.text(model.title),
          ]),
          html.div([attribute.class("editor-page__title-actions")], [
            case show_snippet_info {
              True ->
                html.button(
                  [
                    attribute.type_("button"),
                    attribute.class(
                      "editor-page__title-edit-button editor-page__title-info-button",
                    ),
                    attribute.attribute("aria-label", "Snippet info"),
                    event.on_click(SnippetInfoClicked),
                  ],
                  [
                    html.span(
                      [
                        attribute.class(
                          "editor-page__title-hint editor-page__title-hint--info",
                        ),
                      ],
                      [
                        html.text("Info"),
                      ],
                    ),
                  ],
                )

              False -> html.div([], [])
            },
            case can_edit_title {
              True ->
                html.button(
                  [
                    attribute.type_("button"),
                    attribute.class("editor-page__title-edit-button"),
                    attribute.attribute("aria-label", "Edit title"),
                    event.on_click(TitleClicked),
                  ],
                  [
                    html.span([attribute.class("editor-page__title-hint")], [
                      html.text("Edit"),
                    ]),
                  ],
                )

              False -> html.div([], [])
            },
          ]),
        ]),
      ]),
      title_dialog_view(model),
      add_entry_dialog_view(model),
      edit_entry_dialog_view(model),
      settings_dialog_view(model),
      save_dialog_view(model, current_user_id),
      restore_draft_dialog_view(model),
      snippet_info_dialog_view(model),
      html.div(
        [attribute.class("editor-shell__tabbar")],
        tabbar_children(model),
      ),
      html.div([attribute.class("editor-shell__editor")], [
        element.element(
          "glot-codemirror",
          [
            attribute.id(editor_id),
            attribute.class("editor-shell__codemirror"),
            attribute.attribute("language", language.to_string(model.language)),
            attribute.attribute("value", selected_tab_content(model)),
            attribute.attribute(
              "keyboard-bindings",
              model.editor_settings.keyboard_bindings
                |> editor_settings.keyboard_bindings_to_string(),
            ),
            event.on("change", {
              use value <- decode.subfield(["detail", "value"], decode.string)
              decode.success(SourceCodeChanged(value))
            }),
          ],
          [],
        ),
      ]),
      html.div([attribute.class("editor-shell__actions")], [
        action_button(
          "editor-shell__action-button",
          run_button_text(model.run_state),
          model.run_state == Running,
          RunSubmitted,
        ),
        action_button(
          "editor-shell__action-button",
          save_button_text(model.save_state),
          model.save_state == Saving,
          SaveClicked,
        ),
      ]),
      console_view(model.version_info, model.run_state, model.save_state),
    ]),
  ])
}

pub fn quick_actions(
  model: Model,
  current_user_id: option.Option(Uuid),
) -> List(top_bar.Action(Msg)) {
  case model {
    SupportedLanguage(model) -> quick_actions_for_model(model, current_user_id)
    UnsupportedLanguage(_) | LoadingSnippet(_, _) | LoadError(_) -> []
  }
}

fn quick_actions_for_model(
  model: RealModel,
  current_user_id: option.Option(Uuid),
) -> List(top_bar.Action(Msg)) {
  let base_actions = [
    top_bar.Action(
      label: "Run code",
      description: "Execute the current snippet.",
      shortcut: ["cmd+enter", "ctrl+enter"],
      msg: RunSubmitted,
    ),
    top_bar.Action(
      label: save_action_name(model, current_user_id),
      description: "Save the current snippet state.",
      shortcut: [],
      msg: SaveClicked,
    ),
    top_bar.Action(
      label: "New file",
      description: "Add a new file or stdin input entry.",
      shortcut: [],
      msg: AddEntryClicked,
    ),
    top_bar.Action(
      label: "Settings",
      description: "Open editor settings.",
      shortcut: [],
      msg: SettingsClicked,
    ),
  ]

  let info_actions = case model.slug != option.None {
    True -> [
      top_bar.Action(
        label: "Snippet info",
        description: "View snippet metadata.",
        shortcut: [],
        msg: SnippetInfoClicked,
      ),
    ]
    False -> []
  }

  let title_actions = case
    model.slug == option.None || is_owner(model, current_user_id)
  {
    True -> [
      top_bar.Action(
        label: "Edit title",
        description: "Rename the current snippet.",
        shortcut: [],
        msg: TitleClicked,
      ),
    ]
    False -> []
  }

  base_actions
  |> list.append(info_actions)
  |> list.append(title_actions)
}

fn icon_action_button(
  class_name: String,
  msg: Msg,
  children: List(Element(Msg)),
) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class(class_name),
      event.on_click(msg),
    ],
    children,
  )
}

fn action_button(
  class_name: String,
  label: String,
  disabled: Bool,
  msg: Msg,
) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class(class_name),
      attribute.disabled(disabled),
      event.on_click(msg),
    ],
    [html.text(label)],
  )
}

fn title_dialog_view(model: RealModel) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(title_dialog_id),
      attribute.class("editor-page__dialog"),
      event.on("close", decode.success(TitleDialogClosed)),
    ],
    [
      html.form(
        [
          attribute.class("editor-page__dialog-form"),
          event.on_submit(fn(_) { TitleEditSubmitted }),
        ],
        [
          html.label(
            [
              attribute.for("editor-page-title-input"),
              attribute.class("editor-page__dialog-label"),
            ],
            [html.text("Title")],
          ),
          html.input([
            attribute.id("editor-page-title-input"),
            attribute.name("title"),
            attribute.type_("text"),
            attribute.value(model.title_draft),
            attribute.autofocus(True),
            attribute.class("editor-page__dialog-input"),
            event.on_input(TitleDraftChanged),
          ]),
          html.div([attribute.class("editor-page__dialog-actions")], [
            html.button(
              [
                attribute.type_("button"),
                attribute.class(
                  "editor-page__dialog-button editor-page__dialog-button--secondary",
                ),
                event.on_click(TitleEditCancelled),
              ],
              [html.text("Cancel")],
            ),
            html.button(
              [
                attribute.type_("submit"),
                attribute.class("editor-page__dialog-button"),
              ],
              [html.text("Apply")],
            ),
          ]),
        ],
      ),
    ],
  )
}

fn add_entry_dialog_view(model: RealModel) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(add_entry_dialog_id),
      attribute.class("editor-page__dialog"),
      event.on("close", decode.success(AddEntryDialogClosed)),
    ],
    [
      html.form(
        [
          attribute.class("editor-page__dialog-form"),
          event.on_submit(fn(_) { AddEntrySubmitted }),
        ],
        [
          html.div([attribute.class("editor-page__dialog-toggle-group")], [
            toggle_button(
              "File",
              model.add_entry_kind == AddFileEntry,
              AddFileEntry,
            ),
            toggle_button(
              "stdin",
              model.add_entry_kind == AddStdinEntry,
              AddStdinEntry,
            ),
          ]),
          add_entry_fields_view(model),
          html.div([attribute.class("editor-page__dialog-actions")], [
            html.button(
              [
                attribute.type_("button"),
                attribute.class(
                  "editor-page__dialog-button editor-page__dialog-button--secondary",
                ),
                event.on_click(AddEntryCancelled),
              ],
              [html.text("Cancel")],
            ),
            html.button(
              [
                attribute.type_("submit"),
                attribute.class("editor-page__dialog-button"),
                attribute.disabled(!can_submit_add_entry(model)),
              ],
              [html.text("Add")],
            ),
          ]),
        ],
      ),
    ],
  )
}

fn edit_entry_dialog_view(model: RealModel) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(edit_entry_dialog_id),
      attribute.class("editor-page__dialog"),
      event.on("close", decode.success(EditEntryDialogClosed)),
    ],
    [
      html.form(
        [
          attribute.class("editor-page__dialog-form"),
          event.on_submit(fn(_) { EditEntrySubmitted }),
        ],
        edit_entry_dialog_children(model),
      ),
    ],
  )
}

fn settings_dialog_view(model: RealModel) -> Element(Msg) {
  let custom_run_instructions =
    model.run_instructions_mode_draft == CustomRunInstructions

  html.dialog(
    [
      attribute.id(settings_dialog_id),
      attribute.class("editor-page__dialog"),
      event.on("close", decode.success(SettingsDialogClosed)),
    ],
    [
      html.form(
        [
          attribute.class("editor-page__dialog-form"),
          event.on_submit(fn(_) { SettingsSubmitted }),
        ],
        [
          html.label([attribute.class("editor-page__dialog-label")], [
            html.text("Keyboard bindings"),
          ]),
          html.div([attribute.class("editor-page__dialog-panel")], [
            keyboard_bindings_option(
              "Default",
              "Standard CodeMirror shortcuts.",
              editor_settings.DefaultBindings,
              model.editor_settings_draft.keyboard_bindings,
            ),
            keyboard_bindings_option(
              "Emacs",
              "Enable Emacs-style editing commands.",
              editor_settings.EmacsBindings,
              model.editor_settings_draft.keyboard_bindings,
            ),
            keyboard_bindings_option(
              "Vim",
              "Enable modal Vim keybindings.",
              editor_settings.VimBindings,
              model.editor_settings_draft.keyboard_bindings,
            ),
          ]),
          html.div([attribute.class("editor-page__dialog-divider")], []),
          html.div([attribute.class("editor-page__dialog-section")], [
            html.label([attribute.class("editor-page__dialog-label")], [
              html.text("Run instructions"),
            ]),
            html.div([attribute.class("editor-page__dialog-panel")], [
              html.select(
                [
                  attribute.id("editor-page-run-instructions-mode"),
                  attribute.name("run_instructions_mode"),
                  attribute.class("editor-page__dialog-select"),
                  attribute.value(run_instructions_mode_to_string(
                    model.run_instructions_mode_draft,
                  )),
                  event.on_input(RunInstructionsModeDraftChanged),
                ],
                [
                  html.option(
                    [
                      attribute.value("default"),
                      attribute.selected(
                        model.run_instructions_mode_draft
                        == DefaultRunInstructions,
                      ),
                    ],
                    "Default",
                  ),
                  html.option(
                    [
                      attribute.value("custom"),
                      attribute.selected(
                        model.run_instructions_mode_draft
                        == CustomRunInstructions,
                      ),
                    ],
                    "Custom",
                  ),
                ],
              ),
              html.label(
                [
                  attribute.for("editor-page-build-commands-input"),
                  attribute.class("editor-page__dialog-sublabel"),
                ],
                [html.text("Build commands")],
              ),
              html.textarea(
                [
                  attribute.id("editor-page-build-commands-input"),
                  attribute.name("build_commands"),
                  attribute.rows(2),
                  attribute.class(
                    "editor-page__dialog-input editor-page__dialog-input--multiline",
                  ),
                  attribute.disabled(!custom_run_instructions),
                  event.on_input(RunInstructionsBuildCommandsDraftChanged),
                ],
                model.run_instructions_draft.build_commands_text,
              ),
              html.p([attribute.class("editor-page__dialog-helper-text")], [
                html.text(
                  "One build command per line. Leave blank to skip build.",
                ),
              ]),
              html.label(
                [
                  attribute.for("editor-page-run-command-input"),
                  attribute.class("editor-page__dialog-sublabel"),
                ],
                [html.text("Run command")],
              ),
              html.input([
                attribute.id("editor-page-run-command-input"),
                attribute.name("run_command"),
                attribute.type_("text"),
                attribute.value(model.run_instructions_draft.run_command),
                attribute.class("editor-page__dialog-input"),
                attribute.disabled(!custom_run_instructions),
                event.on_input(RunInstructionsRunCommandDraftChanged),
              ]),
            ]),
          ]),
          html.div([attribute.class("editor-page__dialog-actions")], [
            html.button(
              [
                attribute.type_("button"),
                attribute.class(
                  "editor-page__dialog-button editor-page__dialog-button--secondary",
                ),
                event.on_click(SettingsCancelled),
              ],
              [html.text("Cancel")],
            ),
            html.button(
              [
                attribute.type_("submit"),
                attribute.class("editor-page__dialog-button"),
              ],
              [html.text("Apply")],
            ),
          ]),
        ],
      ),
    ],
  )
}

fn save_dialog_view(
  model: RealModel,
  current_user_id: option.Option(Uuid),
) -> Element(Msg) {
  let children = case current_user_id {
    option.None -> [
      html.div(
        [attribute.class("editor-page__dialog-form")],
        save_dialog_children(model, current_user_id),
      ),
    ]

    option.Some(_) -> [
      html.form(
        [
          attribute.class("editor-page__dialog-form"),
          event.on_submit(fn(_) { SaveConfirmed }),
        ],
        save_dialog_children(model, current_user_id),
      ),
    ]
  }

  html.dialog(
    [
      attribute.id(save_dialog_id),
      attribute.class("editor-page__dialog"),
      event.on("close", decode.success(SaveDialogClosed)),
    ],
    children,
  )
}

fn save_dialog_children(
  model: RealModel,
  current_user_id: option.Option(Uuid),
) -> List(Element(Msg)) {
  case current_user_id {
    option.None -> [
      html.label([attribute.class("editor-page__dialog-label")], [
        html.text("Save snippet"),
      ]),
      html.p([attribute.class("editor-page__dialog-copy")], [
        html.text("You need to log in before you can save snippets. "),
        html.a(
          [
            route.href(route.Login),
            attribute.class("editor-page__dialog-link"),
          ],
          [html.text("Go to login")],
        ),
        html.text("."),
      ]),
      html.div([attribute.class("editor-page__dialog-actions")], [
        html.button(
          [
            attribute.type_("button"),
            attribute.class(
              "editor-page__dialog-button editor-page__dialog-button--secondary",
            ),
            event.on_click(SnippetInfoDismissed),
          ],
          [html.text("Close")],
        ),
      ]),
    ]

    option.Some(_) ->
      case can_choose_save_visibility(model, current_user_id) {
        True -> [
          html.label([attribute.class("editor-page__dialog-label")], [
            html.text("Visibility"),
          ]),
          html.div([attribute.class("editor-page__dialog-panel")], [
            visibility_option(
              "Public",
              "Visible to everyone.",
              snippet_model.Public,
              model.save_visibility_draft,
            ),
            visibility_option(
              "Unlisted",
              "Available through the link only.",
              snippet_model.Unlisted,
              model.save_visibility_draft,
            ),
          ]),
          html.div([attribute.class("editor-page__dialog-actions")], [
            html.button(
              [
                attribute.type_("button"),
                attribute.class(
                  "editor-page__dialog-button editor-page__dialog-button--secondary",
                ),
                event.on_click(SaveCancelled),
              ],
              [html.text("Cancel")],
            ),
            html.button(
              [
                attribute.type_("submit"),
                attribute.class("editor-page__dialog-button"),
              ],
              [html.text("Save")],
            ),
          ]),
        ]

        False -> [
          html.label([attribute.class("editor-page__dialog-label")], [
            html.text("Save snippet"),
          ]),
          html.p([attribute.class("editor-page__dialog-copy")], [
            html.text(
              "You do not own this snippet. Saving will create a new snippet in your account.",
            ),
          ]),
          html.div([attribute.class("editor-page__dialog-actions")], [
            html.button(
              [
                attribute.type_("button"),
                attribute.class(
                  "editor-page__dialog-button editor-page__dialog-button--secondary",
                ),
                event.on_click(SaveCancelled),
              ],
              [html.text("Cancel")],
            ),
            html.button(
              [
                attribute.type_("submit"),
                attribute.class("editor-page__dialog-button"),
              ],
              [html.text("Save new snippet")],
            ),
          ]),
        ]
      }
  }
}

fn restore_draft_dialog_view(model: RealModel) -> Element(Msg) {
  let restore_copy = case model.slug {
    option.None ->
      "A local draft from the last 24 hours was found for this new snippet. Do you want to restore it?"
    option.Some(_) ->
      "A newer local draft was found for this snippet. Do you want to restore your unsaved local changes?"
  }

  let children = case model.pending_restore_draft {
    option.Some(_) -> [
      html.div([attribute.class("editor-page__dialog-form")], [
        html.label([attribute.class("editor-page__dialog-label")], [
          html.text("Restore draft"),
        ]),
        html.p([attribute.class("editor-page__dialog-copy")], [
          html.text(restore_copy),
        ]),
        html.div([attribute.class("editor-page__dialog-actions")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.class(
                "editor-page__dialog-button editor-page__dialog-button--secondary",
              ),
              event.on_click(RestoreDraftDeclined),
            ],
            [html.text("No")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("editor-page__dialog-button"),
              event.on_click(RestoreDraftAccepted),
            ],
            [html.text("Yes")],
          ),
        ]),
      ]),
    ]

    option.None -> []
  }

  html.dialog(
    [
      attribute.id(restore_draft_dialog_id),
      attribute.class("editor-page__dialog"),
      event.on("close", decode.success(RestoreDraftClosed)),
    ],
    children,
  )
}

fn snippet_info_dialog_view(model: RealModel) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(snippet_info_dialog_id),
      attribute.class("editor-page__dialog"),
      event.on("close", decode.success(SnippetInfoClosed)),
    ],
    [
      html.div(
        [attribute.class("editor-page__dialog-form")],
        snippet_info_dialog_children(model),
      ),
    ],
  )
}

fn snippet_info_dialog_children(model: RealModel) -> List(Element(Msg)) {
  case model.slug {
    option.Some(_) -> [
      html.label(
        [
          attribute.class(
            "editor-page__dialog-label editor-page__dialog-label--snippet-info",
          ),
        ],
        [
          html.text("Snippet info"),
        ],
      ),
      html.div([attribute.class("editor-page__dialog-panel")], [
        snippet_info_row("Title", model.title),
        snippet_info_row("Language", language.name(model.language)),
        snippet_info_row("Author", snippet_owner_label(model)),
        snippet_info_row(
          "Visibility",
          snippet_model.visibility_to_string(model.visibility)
            |> string.uppercase,
        ),
        snippet_info_row("URL", snippet_url(model)),
        snippet_info_row("Created", optional_timestamp_label(model.created_at)),
        snippet_info_row("Updated", optional_timestamp_label(model.updated_at)),
      ]),
      html.div([attribute.class("editor-page__dialog-actions")], [
        html.button(
          [
            attribute.type_("button"),
            attribute.class(
              "editor-page__dialog-button editor-page__dialog-button--secondary",
            ),
            event.on_click(SnippetInfoDismissed),
          ],
          [html.text("Close")],
        ),
      ]),
    ]

    option.None -> [
      html.label(
        [
          attribute.class(
            "editor-page__dialog-label editor-page__dialog-label--snippet-info",
          ),
        ],
        [
          html.text("Snippet info"),
        ],
      ),
      html.div([attribute.class("editor-page__dialog-panel")], [
        snippet_info_row("Title", model.title),
        snippet_info_row("Language", language.name(model.language)),
      ]),
      html.p([attribute.class("editor-page__dialog-copy")], [
        html.text("This snippet has not been saved yet."),
      ]),
      html.div([attribute.class("editor-page__dialog-actions")], [
        html.button(
          [
            attribute.type_("button"),
            attribute.class(
              "editor-page__dialog-button editor-page__dialog-button--secondary",
            ),
            event.on_click(SnippetInfoDismissed),
          ],
          [html.text("Close")],
        ),
      ]),
    ]
  }
}

fn snippet_info_row(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("editor-page__dialog-panel")], [
    html.span([attribute.class("editor-page__dialog-sublabel")], [
      html.text(label),
    ]),
    html.p([attribute.class("editor-page__dialog-copy")], [
      html.text(value),
    ]),
  ])
}

fn snippet_url(model: RealModel) -> String {
  case model.slug {
    option.Some(slug) ->
      "https://glot.io" <> route.to_string(route.Snippet(slug))
    option.None -> ""
  }
}

fn edit_entry_dialog_children(model: RealModel) -> List(Element(Msg)) {
  case model.selected_tab {
    FileTab(_) -> [
      html.label(
        [
          attribute.for("editor-page-edit-entry-input"),
          attribute.class("editor-page__dialog-label"),
        ],
        [html.text("Filename")],
      ),
      html.input([
        attribute.id("editor-page-edit-entry-input"),
        attribute.name("filename"),
        attribute.type_("text"),
        attribute.maxlength(30),
        attribute.value(model.edit_entry_filename),
        attribute.autofocus(True),
        attribute.class("editor-page__dialog-input"),
        event.on_input(EditEntryFilenameChanged),
      ]),
      html.div(
        [attribute.class("editor-page__dialog-actions")],
        file_edit_actions(model),
      ),
    ]

    StdinTab -> [
      html.p([attribute.class("editor-page__dialog-copy")], [
        html.text("Delete the <stdin> tab and keep only source files."),
      ]),
      html.div([attribute.class("editor-page__dialog-actions")], [
        html.button(
          [
            attribute.type_("button"),
            attribute.class(
              "editor-page__dialog-button editor-page__dialog-button--danger",
            ),
            event.on_click(EditEntryDeleted),
          ],
          [html.text("Delete <stdin>")],
        ),
        html.button(
          [
            attribute.type_("button"),
            attribute.class(
              "editor-page__dialog-button editor-page__dialog-button--secondary",
            ),
            event.on_click(EditEntryCancelled),
          ],
          [html.text("Close")],
        ),
      ]),
    ]
  }
}

fn file_edit_actions(model: RealModel) -> List(Element(Msg)) {
  let delete_button = case can_delete_selected_file(model) {
    True -> [
      html.button(
        [
          attribute.type_("button"),
          attribute.class(
            "editor-page__dialog-button editor-page__dialog-button--danger",
          ),
          event.on_click(EditEntryDeleted),
        ],
        [html.text("Delete file")],
      ),
    ]

    False -> []
  }

  list.append(delete_button, [
    html.button(
      [
        attribute.type_("button"),
        attribute.class(
          "editor-page__dialog-button editor-page__dialog-button--secondary",
        ),
        event.on_click(EditEntryCancelled),
      ],
      [html.text("Cancel")],
    ),
    html.button(
      [
        attribute.type_("submit"),
        attribute.class("editor-page__dialog-button"),
        attribute.disabled(!can_submit_edit_entry(model)),
      ],
      [html.text("Save")],
    ),
  ])
}

fn toggle_button(
  label: String,
  is_selected: Bool,
  kind: AddEntryKind,
) -> Element(Msg) {
  let class_name = case is_selected {
    True -> "editor-page__dialog-toggle editor-page__dialog-toggle--selected"
    False -> "editor-page__dialog-toggle"
  }

  html.button(
    [
      attribute.type_("button"),
      attribute.class(class_name),
      attribute.attribute("aria-pressed", bool_attribute(is_selected)),
      event.on_click(AddEntryKindSelected(kind)),
    ],
    [html.text(label)],
  )
}

fn add_entry_fields_view(model: RealModel) -> Element(Msg) {
  case model.add_entry_kind {
    AddFileEntry ->
      html.div([attribute.class("editor-page__dialog-panel")], [
        html.label(
          [
            attribute.for("editor-page-filename-input"),
            attribute.class("editor-page__dialog-label"),
          ],
          [html.text("Filename")],
        ),
        html.input([
          attribute.id("editor-page-filename-input"),
          attribute.name("filename"),
          attribute.type_("text"),
          attribute.maxlength(30),
          attribute.value(model.add_entry_filename),
          attribute.autofocus(True),
          attribute.class("editor-page__dialog-input"),
          event.on_input(AddEntryFilenameChanged),
        ]),
      ])

    AddStdinEntry ->
      html.div([attribute.class("editor-page__dialog-panel")], [
        html.p([attribute.class("editor-page__dialog-copy")], [
          html.text(add_stdin_message(model.stdin)),
        ]),
      ])
  }
}

fn keyboard_bindings_option(
  label: String,
  description: String,
  value: editor_settings.KeyboardBindings,
  selected: editor_settings.KeyboardBindings,
) -> Element(Msg) {
  let is_selected = value == selected
  let class_name = case is_selected {
    True ->
      "editor-page__settings-option editor-page__settings-option--selected"
    False -> "editor-page__settings-option"
  }

  html.button(
    [
      attribute.type_("button"),
      attribute.class(class_name),
      attribute.attribute("aria-pressed", bool_attribute(is_selected)),
      event.on_click(KeyboardBindingsDraftSelected(value)),
    ],
    [
      html.span([attribute.class("editor-page__settings-option-title")], [
        html.text(label),
      ]),
      html.span([attribute.class("editor-page__settings-option-copy")], [
        html.text(description),
      ]),
    ],
  )
}

fn visibility_option(
  label: String,
  description: String,
  value: snippet_model.Visibility,
  selected: snippet_model.Visibility,
) -> Element(Msg) {
  let is_selected = value == selected
  let class_name = case is_selected {
    True ->
      "editor-page__settings-option editor-page__settings-option--selected"
    False -> "editor-page__settings-option"
  }

  html.button(
    [
      attribute.type_("button"),
      attribute.class(class_name),
      attribute.attribute("aria-pressed", bool_attribute(is_selected)),
      event.on_click(SaveVisibilityDraftSelected(value)),
    ],
    [
      html.span([attribute.class("editor-page__settings-option-title")], [
        html.text(label),
      ]),
      html.span([attribute.class("editor-page__settings-option-copy")], [
        html.text(description),
      ]),
    ],
  )
}

fn snippet_owner_label(model: RealModel) -> String {
  case model.owner_username {
    option.Some(username) -> username
    option.None ->
      case model.owner_user_id {
        option.Some(user_id) -> uuid.to_string(user_id)
        option.None -> "Unknown"
      }
  }
}

fn optional_timestamp_label(value: option.Option(Timestamp)) -> String {
  case value {
    option.Some(timestamp) -> timestamp_label(timestamp)
    option.None -> "Unknown"
  }
}

fn timestamp_label(value: Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}

fn tabbar_children(model: RealModel) -> List(Element(Msg)) {
  [
    icon_action_button("editor-shell__settings-button", SettingsClicked, [
      icons.cog_6_tooth(),
    ]),
    html.div([attribute.class("editor-shell__tab-scroll")], [
      html.div([attribute.class("editor-shell__tab-strip")], tab_views(model)),
    ]),
    selected_tab_action_button(model),
    icon_action_button("editor-shell__tab-action-button", AddEntryClicked, [
      icons.document_plus(),
    ]),
  ]
}

fn tab_views(model: RealModel) -> List(Element(Msg)) {
  let file_tabs = file_tab_views(model.files, model.selected_tab, 0)
  case model.stdin {
    option.Some(_) ->
      list.append(file_tabs, [
        tab_button("<stdin>", StdinTab, model.selected_tab == StdinTab),
      ])

    option.None -> file_tabs
  }
}

fn file_tab_views(
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

fn tab_button(label: String, tab: EditorTab, is_selected: Bool) -> Element(Msg) {
  let class_name = case is_selected {
    True -> "editor-shell__tab editor-shell__tab--selected"
    False -> "editor-shell__tab"
  }

  html.button(
    [
      attribute.type_("button"),
      attribute.class(class_name),
      attribute.attribute("aria-selected", bool_attribute(is_selected)),
      event.on_click(TabSelected(tab)),
    ],
    [html.span([], [html.text(label)])],
  )
}

fn selected_tab_action_button(model: RealModel) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class("editor-shell__tab-meta-button"),
      attribute.attribute(
        "aria-label",
        selected_tab_action_label(model.selected_tab),
      ),
      event.on_click(SelectedTabActionClicked),
    ],
    [
      html.span([attribute.class("editor-shell__tab-meta-pill")], [
        html.text("Edit"),
      ]),
    ],
  )
}

fn is_owner(model: RealModel, current_user_id: option.Option(Uuid)) -> Bool {
  model.owner_user_id == current_user_id
}

fn can_choose_save_visibility(
  model: RealModel,
  current_user_id: option.Option(Uuid),
) -> Bool {
  case current_user_id {
    option.None -> False
    option.Some(_) ->
      model.slug == option.None || is_owner(model, current_user_id)
  }
}

fn save_operation(
  model: RealModel,
  current_user_id: option.Option(Uuid),
) -> SaveOperation {
  case model.slug, is_owner(model, current_user_id) {
    option.Some(slug), True -> UpdateSnippet(slug)
    _, _ -> CreateSnippet
  }
}

fn save_visibility(
  model: RealModel,
  current_user_id: option.Option(Uuid),
) -> snippet_model.Visibility {
  case can_choose_save_visibility(model, current_user_id) {
    True -> model.save_visibility_draft
    False -> model.visibility
  }
}

fn save_action_name(
  model: RealModel,
  current_user_id: option.Option(Uuid),
) -> String {
  case save_operation(model, current_user_id) {
    CreateSnippet -> "Create snippet"
    UpdateSnippet(_) -> "Update snippet"
  }
}

fn reset_save_dialog_draft(model: RealModel) -> RealModel {
  RealModel(..model, save_visibility_draft: model.visibility)
}

fn new_editor_model(
  lang: language.Language,
  settings: editor_settings.EditorSettings,
  pending_restore_draft: option.Option(editor_draft.StoredEditorDraft),
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
    selected_tab: FileTab(0),
    add_entry_kind: AddFileEntry,
    add_entry_filename: "",
    edit_entry_filename: default_file_name([default_file], FileTab(0)),
    editor_settings: settings,
    editor_settings_draft: settings,
    run_instructions_override: option.None,
    run_instructions_mode_draft: DefaultRunInstructions,
    run_instructions_draft: run_instructions_to_draft(
      default_run_instructions(lang, [default_file]),
    ),
    save_visibility_draft: snippet_model.Unlisted,
    pending_restore_draft: pending_restore_draft,
    version_info: option.None,
    run_state: Idle,
    save_state: SaveIdle,
  )
}

fn init_new_effect_for_model(model: Model) -> Effect(Msg) {
  effect.batch([version_run_effect_for_model(model), restore_draft_effect(model)])
}

fn restore_draft_effect(model: Model) -> Effect(Msg) {
  case model {
    SupportedLanguage(real_model) ->
      case real_model.pending_restore_draft {
        option.Some(_) -> app_dialog.open_next_frame(restore_draft_dialog_id)
        option.None -> effect.none()
      }

    _ -> effect.none()
  }
}

fn apply_editor_draft(
  model: RealModel,
  draft: editor_draft.EditorDraft,
) -> RealModel {
  let files = draft.files
  let stdin = draft.stdin
  let selected_tab = initial_selected_tab(files, stdin)
  let run_instructions_override = draft.run_instructions_override
  let run_instructions = case run_instructions_override {
    option.Some(instructions) -> instructions
    option.None -> default_run_instructions(draft.language, files)
  }

  RealModel(
    ..model,
    title: draft.title,
    title_draft: draft.title,
    language: draft.language,
    files: files,
    stdin: stdin,
    selected_tab: selected_tab,
    add_entry_kind: default_add_entry_kind(stdin),
    edit_entry_filename: default_file_name(files, selected_tab),
    run_instructions_override: run_instructions_override,
    run_instructions_mode_draft: case run_instructions_override {
      option.Some(_) -> CustomRunInstructions
      option.None -> DefaultRunInstructions
    },
    run_instructions_draft: run_instructions_to_draft(run_instructions),
    pending_restore_draft: option.None,
  )
}

fn new_snippet_draft_from_model(
  model: RealModel,
) -> editor_draft.EditorDraft {
  editor_draft.EditorDraft(
    title: model.title,
    language: model.language,
    files: model.files,
    stdin: model.stdin,
    run_instructions_override: model.run_instructions_override,
  )
}

fn save_editor_draft(model: RealModel) -> Effect(msg) {
  case model.slug {
    option.None ->
      editor_draft.save_new_snippet(
        model.language,
        new_snippet_draft_from_model(model),
      )
    option.Some(slug) ->
      editor_draft.save_existing_snippet(
        slug,
        new_snippet_draft_from_model(model),
      )
  }
}

fn clear_editor_draft(model: RealModel) -> Effect(msg) {
  case model.slug {
    option.None -> editor_draft.clear_new_snippet(model.language)
    option.Some(slug) -> editor_draft.clear_existing_snippet(slug)
  }
}

fn load_existing_restore_draft(
  slug: String,
  updated_at: Timestamp,
) -> #(option.Option(editor_draft.StoredEditorDraft), Effect(msg)) {
  case editor_draft.load_existing_snippet(slug) {
    option.Some(draft) ->
      case is_newer_than_saved_snippet(draft.saved_at_ms, updated_at) {
        True -> #(option.Some(draft), effect.none())
        False -> #(option.None, editor_draft.clear_existing_snippet(slug))
      }

    option.None -> #(option.None, effect.none())
  }
}

fn is_newer_than_saved_snippet(saved_at_ms: Int, updated_at: Timestamp) -> Bool {
  saved_at_ms > timestamp_helpers.to_microseconds(updated_at) / 1000
}

fn focus_editor() -> Effect(msg) {
  app_dialog.focus(editor_id)
}

fn run_button_text(run_state: RunState) -> String {
  case run_state {
    Running -> "Running..."
    _ -> "Run"
  }
}

fn save_button_text(save_state: SaveState) -> String {
  case save_state {
    Saving -> "Saving..."
    _ -> "Save"
  }
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

fn run_instructions_mode(model: RealModel) -> RunInstructionsMode {
  case model.run_instructions_override {
    option.Some(_) -> CustomRunInstructions
    option.None -> DefaultRunInstructions
  }
}

fn run_instructions_mode_to_string(mode: RunInstructionsMode) -> String {
  case mode {
    DefaultRunInstructions -> "default"
    CustomRunInstructions -> "custom"
  }
}

fn run_instructions_mode_from_string(value: String) -> RunInstructionsMode {
  case value {
    "custom" -> CustomRunInstructions
    _ -> DefaultRunInstructions
  }
}

fn run_instructions_from_draft(
  draft: RunInstructionsDraft,
) -> language.RunInstructions {
  language.RunInstructions(
    build_commands: draft.build_commands_text
      |> string.split("\n")
      |> list.map(string.trim)
      |> list.filter(fn(command) { command != "" }),
    run_command: string.trim(draft.run_command),
  )
}

fn default_run_instructions(
  lang: language.Language,
  files: List(snippet_model.File),
) -> language.RunInstructions {
  let default_name = language.default_filename(lang)
  let main_file = select_main_file_name(files, default_name)
  let other_files =
    files
    |> list.map(fn(file) { file.name })
    |> remove_first_matching_file_name(main_file)

  language.run_instructions(lang, main_file, other_files)
}

fn effective_run_instructions(model: RealModel) -> language.RunInstructions {
  case model.run_instructions_override {
    option.Some(run_instructions) -> run_instructions
    option.None -> default_run_instructions(model.language, model.files)
  }
}

fn run_instructions_override_from_draft(
  model: RealModel,
) -> option.Option(language.RunInstructions) {
  case model.run_instructions_mode_draft {
    DefaultRunInstructions -> option.None
    CustomRunInstructions ->
      option.Some(run_instructions_from_draft(model.run_instructions_draft))
  }
}

fn select_main_file_name(
  files: List(snippet_model.File),
  default_name: String,
) -> String {
  case find_file_name(files, default_name) {
    option.Some(name) -> name
    option.None -> first_file_name(files)
  }
}

fn find_file_name(
  files: List(snippet_model.File),
  target: String,
) -> option.Option(String) {
  case files {
    [] -> option.None
    [snippet_model.File(name:, ..), ..rest] ->
      case name == target {
        True -> option.Some(name)
        False -> find_file_name(rest, target)
      }
  }
}

fn first_file_name(files: List(snippet_model.File)) -> String {
  case files {
    [snippet_model.File(name:, ..), ..] -> name
    [] -> ""
  }
}

fn remove_first_matching_file_name(
  files: List(String),
  target: String,
) -> List(String) {
  case files {
    [] -> []
    [name, ..rest] ->
      case name == target {
        True -> rest
        False -> [name, ..remove_first_matching_file_name(rest, target)]
      }
  }
}

fn version_run_effect_for_model(model: Model) -> Effect(Msg) {
  case model {
    SupportedLanguage(real_model) -> version_run_effect(real_model.language)
    _ -> effect.none()
  }
}

fn version_run_effect(lang: language.Language) -> Effect(Msg) {
  api.get_language_version(
    run.GetLanguageVersionRequest(language: lang),
    VersionRunFinished,
  )
}

fn console_view(
  version_info: option.Option(String),
  run_state: RunState,
  save_state: SaveState,
) -> Element(Msg) {
  html.div([attribute.class("editor-shell__console")], [
    console_header_view(version_info, run_state, save_state),
    html.div([attribute.class("editor-shell__console-body")], [
      console_content(version_info, run_state, save_state),
    ]),
  ])
}

fn console_header_view(
  version_info: option.Option(String),
  run_state: RunState,
  save_state: SaveState,
) -> Element(Msg) {
  case save_state, run_state, version_info {
    SaveIdle, Completed(Ok(_)), _ -> html.div([], [])
    _, _, _ ->
      html.div([attribute.class("editor-shell__console-header")], [
        html.text("INFO"),
      ])
  }
}

fn console_content(
  version_info: option.Option(String),
  run_state: RunState,
  save_state: SaveState,
) -> Element(Msg) {
  case save_state {
    SaveError(message) -> console_block("SAVE FAILED", message)

    Saving -> console_block("", "Saving snippet...")

    Saved(slug) -> console_block("", "Saved snippet: " <> slug)

    SaveIdle -> run_console_content(version_info, run_state)
  }
}

fn run_console_content(
  version_info: option.Option(String),
  run_state: RunState,
) -> Element(Msg) {
  case run_state {
    Idle ->
      case version_info {
        option.Some(stdout) -> console_block("", stdout <> "\nREADY.")
        option.None -> html.div([], [])
      }

    Running -> console_block("", "Running snippet...")

    RequestError(message) -> console_block("RUN FAILED", message)

    Completed(result) ->
      case result {
        Ok(success) -> successful_run_console(success)

        Error(failure) -> console_block("RUN FAILED", failure.message)
      }
  }
}

fn successful_run_console(success: run.SuccessfulRun) -> Element(Msg) {
  let run.SuccessfulRun(duration:, stdout:, stderr:, error:) = success

  case stdout != "" {
    True ->
      html.div([], [
        result_panel("stdout", stdout, option.Some(duration)),
        optional_result_panel("stderr", stderr),
        optional_result_panel("error", error),
      ])

    False ->
      case stderr != "" {
        True ->
          html.div([], [
            result_panel("stderr", stderr, option.Some(duration)),
            optional_result_panel("error", error),
          ])

        False ->
          case error != "" {
            True -> result_panel("error", error, option.Some(duration))
            False -> console_block("", "READY.")
          }
      }
  }
}

fn optional_result_panel(label: String, content: String) -> Element(Msg) {
  case content == "" {
    True -> html.div([], [])
    False -> result_panel(label, content, option.None)
  }
}

fn console_block(label: String, content: String) -> Element(Msg) {
  let label_view = case label == "" {
    True -> html.div([], [])
    False ->
      html.div([attribute.class("editor-shell__console-label")], [
        html.text(label),
      ])
  }

  html.div([attribute.class("editor-shell__console-section")], [
    label_view,
    html.pre([attribute.class("editor-shell__console-pre")], [
      html.text(content),
    ]),
  ])
}

fn result_panel(
  label: String,
  content: String,
  duration: option.Option(Int),
) -> Element(Msg) {
  html.div([attribute.class("editor-shell__result-panel")], [
    html.div([attribute.class(result_header_class(label))], [
      html.span([attribute.class("editor-shell__result-title")], [
        html.text(string.uppercase(label)),
      ]),
      result_duration_view(duration),
    ]),
    html.div([attribute.class("editor-shell__result-body")], [
      html.pre([attribute.class("editor-shell__result-pre")], [
        html.text(content),
      ]),
    ]),
  ])
}

fn result_duration_view(duration: option.Option(Int)) -> Element(Msg) {
  case duration {
    option.Some(value) ->
      html.span([attribute.class("editor-shell__result-duration")], [
        html.text(duration_in_ms_label(value)),
      ])

    option.None -> html.span([], [])
  }
}

fn result_header_class(label: String) -> String {
  case label {
    "stdout" ->
      "editor-shell__result-header editor-shell__result-header--stdout"
    "stderr" ->
      "editor-shell__result-header editor-shell__result-header--stderr"
    "error" -> "editor-shell__result-header editor-shell__result-header--error"
    _ -> "editor-shell__result-header"
  }
}

fn title_or_default(title: String) -> String {
  case title == "" {
    True -> "Hello World"
    False -> title
  }
}

fn stdin_option(stdin: String) -> option.Option(String) {
  case stdin == "" {
    True -> option.None
    False -> option.Some(stdin)
  }
}

fn stdin_to_string(stdin: option.Option(String)) -> String {
  case stdin {
    option.Some(content) -> content
    option.None -> ""
  }
}

fn initial_selected_tab(
  files: List(snippet_model.File),
  stdin: option.Option(String),
) -> EditorTab {
  case files {
    [_first, ..] -> FileTab(0)
    [] ->
      case stdin {
        option.Some(_) -> StdinTab
        option.None -> FileTab(0)
      }
  }
}

fn default_add_entry_kind(stdin: option.Option(String)) -> AddEntryKind {
  case stdin {
    option.Some(_) -> AddFileEntry
    option.None -> AddFileEntry
  }
}

fn reset_add_entry_draft(model: RealModel) -> RealModel {
  RealModel(
    ..model,
    add_entry_kind: default_add_entry_kind(model.stdin),
    add_entry_filename: "",
  )
}

fn reset_edit_entry_draft(model: RealModel) -> RealModel {
  RealModel(
    ..model,
    edit_entry_filename: default_file_name(model.files, model.selected_tab),
  )
}

fn add_entry(model: RealModel) -> option.Option(RealModel) {
  case model.add_entry_kind {
    AddFileEntry -> add_file_entry(model)
    AddStdinEntry -> add_stdin_entry(model)
  }
}

fn add_file_entry(model: RealModel) -> option.Option(RealModel) {
  let filename = string.trim(model.add_entry_filename)
  case
    !is_valid_filename_length(filename)
    || file_name_exists(model.files, filename)
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
        ),
      )
    }
  }
}

fn add_stdin_entry(model: RealModel) -> option.Option(RealModel) {
  case model.stdin {
    option.Some(_) -> option.None
    option.None ->
      option.Some(
        RealModel(
          ..model,
          stdin: option.Some(""),
          selected_tab: StdinTab,
          add_entry_filename: "",
        ),
      )
  }
}

fn can_submit_add_entry(model: RealModel) -> Bool {
  case model.add_entry_kind {
    AddFileEntry -> {
      let filename = string.trim(model.add_entry_filename)
      is_valid_filename_length(filename)
      && !file_name_exists(model.files, filename)
    }

    AddStdinEntry ->
      case model.stdin {
        option.Some(_) -> False
        option.None -> True
      }
  }
}

fn add_stdin_message(stdin: option.Option(String)) -> String {
  case stdin {
    option.Some(_) -> "<stdin> already exists for this snippet."
    option.None -> "Add a dedicated <stdin> tab for runtime input."
  }
}

fn file_name_exists(files: List(snippet_model.File), filename: String) -> Bool {
  case files {
    [] -> False
    [snippet_model.File(name:, ..), ..rest] ->
      name == filename || file_name_exists(rest, filename)
  }
}

fn can_submit_edit_entry(model: RealModel) -> Bool {
  case model.selected_tab {
    StdinTab -> False
    FileTab(index) -> {
      let filename = string.trim(model.edit_entry_filename)
      is_valid_filename_length(filename)
      && !file_name_exists_except(model.files, filename, index)
    }
  }
}

fn can_delete_selected_file(model: RealModel) -> Bool {
  case model.selected_tab {
    FileTab(_) -> list.length(model.files) > 1
    StdinTab -> False
  }
}

fn rename_selected_file(model: RealModel) -> option.Option(RealModel) {
  case model.selected_tab {
    StdinTab -> option.None
    FileTab(index) -> {
      let filename = string.trim(model.edit_entry_filename)
      case
        !is_valid_filename_length(filename)
        || file_name_exists_except(model.files, filename, index)
      {
        True -> option.None
        False ->
          option.Some(
            RealModel(
              ..model,
              files: rename_file_at(model.files, index, filename),
            ),
          )
      }
    }
  }
}

fn delete_selected_entry(model: RealModel) -> option.Option(RealModel) {
  case model.selected_tab {
    StdinTab ->
      option.Some(
        RealModel(
          ..model,
          stdin: option.None,
          selected_tab: FileTab(0),
          edit_entry_filename: default_file_name(model.files, FileTab(0)),
        ),
      )

    FileTab(index) ->
      case list.length(model.files) > 1 {
        False -> option.None
        True -> {
          let next_files = remove_file_at(model.files, index)
          let next_tab = case index >= list.length(next_files) {
            True -> FileTab(list.length(next_files) - 1)
            False -> FileTab(index)
          }

          option.Some(
            RealModel(
              ..model,
              files: next_files,
              selected_tab: next_tab,
              edit_entry_filename: default_file_name(next_files, next_tab),
            ),
          )
        }
      }
  }
}

fn default_file_name(files: List(snippet_model.File), tab: EditorTab) -> String {
  case tab {
    FileTab(index) -> file_name_at(files, index)
    StdinTab -> ""
  }
}

fn file_name_at(files: List(snippet_model.File), index: Int) -> String {
  case files, index {
    [snippet_model.File(name:, ..), ..], 0 -> name
    [_first, ..rest], _ -> file_name_at(rest, index - 1)
    [], _ -> ""
  }
}

fn file_name_exists_except(
  files: List(snippet_model.File),
  filename: String,
  skip_index: Int,
) -> Bool {
  case files, skip_index {
    [], _ -> False
    [snippet_model.File(_name, ..), ..rest], 0 ->
      file_name_exists_except(rest, filename, -1)
    [snippet_model.File(name:, ..), ..rest], _ ->
      name == filename
      || file_name_exists_except(rest, filename, skip_index - 1)
  }
}

fn tab_label(filename: String) -> String {
  case string.length(filename) > 10 {
    False -> filename
    True -> truncate_filename(filename)
  }
}

fn truncate_filename(filename: String) -> String {
  let parts = string.split(filename, ".")

  case list.reverse(parts) {
    [extension, stem, ..rest] ->
      string_helpers.truncate_stem_middle(
        string.join(list.reverse([stem, ..rest]), "."),
        10,
      )
      <> "."
      <> extension

    _ -> string_helpers.truncate_stem_middle(filename, 10)
  }
}

fn selected_tab_content(model: RealModel) -> String {
  case model.selected_tab {
    FileTab(index) -> file_content_at(model.files, index)
    StdinTab ->
      case model.stdin {
        option.Some(content) -> content
        option.None -> ""
      }
  }
}

fn file_content_at(files: List(snippet_model.File), index: Int) -> String {
  case files, index {
    [snippet_model.File(content:, ..), ..], 0 -> content
    [_first, ..rest], _ -> file_content_at(rest, index - 1)
    [], _ -> ""
  }
}

fn update_selected_tab_content(model: RealModel, content: String) -> RealModel {
  case model.selected_tab {
    FileTab(index) ->
      RealModel(
        ..model,
        files: update_file_content_at(model.files, index, content),
      )
    StdinTab -> RealModel(..model, stdin: option.Some(content))
  }
}

fn update_file_content_at(
  files: List(snippet_model.File),
  index: Int,
  content: String,
) -> List(snippet_model.File) {
  case files, index {
    [snippet_model.File(name:, ..), ..rest], 0 -> [
      snippet_model.File(name: name, content: content),
      ..rest
    ]

    [first, ..rest], _ -> [
      first,
      ..update_file_content_at(rest, index - 1, content)
    ]

    [], _ -> []
  }
}

fn rename_file_at(
  files: List(snippet_model.File),
  index: Int,
  filename: String,
) -> List(snippet_model.File) {
  case files, index {
    [snippet_model.File(content:, ..), ..rest], 0 -> [
      snippet_model.File(name: filename, content: content),
      ..rest
    ]

    [first, ..rest], _ -> [first, ..rename_file_at(rest, index - 1, filename)]

    [], _ -> []
  }
}

fn remove_file_at(
  files: List(snippet_model.File),
  index: Int,
) -> List(snippet_model.File) {
  case files, index {
    [_first, ..rest], 0 -> rest
    [first, ..rest], _ -> [first, ..remove_file_at(rest, index - 1)]
    [], _ -> []
  }
}

fn duration_in_ms_label(duration_ns: Int) -> String {
  let hundredths_of_ms =
    int.to_float(duration_ns) /. 10_000.0
    |> float.round

  let whole_ms = hundredths_of_ms / 100
  let fractional_ms =
    hundredths_of_ms % 100
    |> int.to_string
    |> string.pad_start(to: 2, with: "0")

  int.to_string(whole_ms) <> "." <> fractional_ms <> "ms"
}

fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn is_valid_filename_length(filename: String) -> Bool {
  filename != "" && string.length(filename) <= 30
}

fn selected_tab_action_label(tab: EditorTab) -> String {
  case tab {
    FileTab(_) -> "Edit selected file"
    StdinTab -> "Manage stdin tab"
  }
}
