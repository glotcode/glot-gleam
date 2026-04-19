import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option
import gleam/pair
import gleam/string
import glot_core/api_action
import glot_core/language
import glot_core/run
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_frontend/api
import glot_frontend/editor_dialog
import glot_frontend/icons
import glot_frontend/route
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import youid/uuid.{type Uuid}

pub type Model {
  UnsupportedLanguage(String)
  LoadingSnippet(String)
  LoadError(String)
  SupportedLanguage(RealModel)
}

pub type RealModel {
  RealModel(
    slug: option.Option(String),
    owner_user_id: option.Option(Uuid),
    title: String,
    title_draft: String,
    language: language.Language,
    files: List(snippet_model.File),
    stdin: option.Option(String),
    selected_tab: EditorTab,
    add_entry_kind: AddEntryKind,
    add_entry_filename: String,
    edit_entry_filename: String,
    run_state: RunState,
    save_state: SaveState,
  )
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

pub fn init_new(language: String) -> #(Model, Effect(Msg)) {
  let model = case language.from_string(language) {
    option.Some(lang) -> {
      let default_file = snippet_model.default_file(lang)
      SupportedLanguage(RealModel(
        slug: option.None,
        owner_user_id: option.None,
        title: "Hello World",
        title_draft: "Hello World",
        language: lang,
        files: [default_file],
        stdin: option.None,
        selected_tab: FileTab(0),
        add_entry_kind: AddFileEntry,
        add_entry_filename: "",
        edit_entry_filename: default_file_name([default_file], FileTab(0)),
        run_state: Idle,
        save_state: SaveIdle,
      ))
    }

    option.None -> UnsupportedLanguage(language)
  }

  #(model, effect.none())
}

pub fn init_existing(slug: String) -> #(Model, Effect(Msg)) {
  #(
    LoadingSnippet(slug),
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
  TabSelected(EditorTab)
  SourceCodeChanged(String)
  RunSubmitted
  RunFinished(api.ApiResponse(run.RunResult))
  SaveSubmitted
  SaveFinished(api.ApiResponse(snippet_dto.SnippetResponse))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model, msg {
    LoadingSnippet(_), SnippetLoaded(result) -> {
      case result {
        api.ApiSuccess(response) -> {
          let files = response.data.files
          let stdin = stdin_option(response.data.stdin)

          #(
            SupportedLanguage(RealModel(
              slug: option.Some(response.slug),
              owner_user_id: option.Some(response.user.id),
              title: title_or_default(response.data.title),
              title_draft: title_or_default(response.data.title),
              language: response.data.language,
              files: files,
              stdin: stdin,
              selected_tab: initial_selected_tab(files, stdin),
              add_entry_kind: default_add_entry_kind(stdin),
              add_entry_filename: "",
              edit_entry_filename: default_file_name(
                files,
                initial_selected_tab(files, stdin),
              ),
              run_state: Idle,
              save_state: SaveIdle,
            )),
            effect.none(),
          )
        }

        api.ApiFailure(error) -> #(LoadError(error.message), effect.none())

        api.HttpFailure(_) ->
          #(LoadError("Could not load snippet."), effect.none())
      }
    }

    UnsupportedLanguage(_), _ -> #(model, effect.none())
    LoadingSnippet(_), _ -> #(model, effect.none())
    LoadError(_), _ -> #(model, effect.none())
    SupportedLanguage(model), _ ->
      update_helper(model, msg)
      |> pair.map_first(SupportedLanguage)
  }
}

pub fn update_helper(model: RealModel, msg: Msg) -> #(RealModel, Effect(Msg)) {
  case msg {
    SnippetLoaded(_) -> #(model, effect.none())

    TitleClicked -> #(
      RealModel(..model, title_draft: model.title),
      editor_dialog.open_title_dialog(),
    )

    TitleDraftChanged(title_draft) -> #(
      RealModel(..model, title_draft: title_draft),
      effect.none(),
    )

    TitleEditCancelled -> #(
      RealModel(..model, title_draft: model.title),
      editor_dialog.close_title_dialog(),
    )

    TitleEditSubmitted -> #(
      RealModel(..model, title: model.title_draft),
      editor_dialog.close_title_dialog(),
    )

    TitleDialogClosed -> #(
      RealModel(..model, title_draft: model.title),
      editor_dialog.focus_editor(),
    )

    AddEntryClicked -> #(
      RealModel(
        ..model,
        add_entry_kind: default_add_entry_kind(model.stdin),
        add_entry_filename: "",
      ),
      editor_dialog.open_add_entry_dialog(),
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
      editor_dialog.close_add_entry_dialog(),
    )

    AddEntrySubmitted -> {
      case add_entry(model) {
        option.Some(next_model) ->
          #(next_model, editor_dialog.close_add_entry_dialog())

        option.None ->
          #(model, effect.none())
      }
    }

    AddEntryDialogClosed -> #(
      reset_add_entry_draft(model),
      editor_dialog.focus_editor(),
    )

    SelectedTabActionClicked -> #(
      RealModel(
        ..model,
        edit_entry_filename: default_file_name(model.files, model.selected_tab),
      ),
      editor_dialog.open_edit_entry_dialog(),
    )

    EditEntryFilenameChanged(filename) -> #(
      RealModel(..model, edit_entry_filename: filename),
      effect.none(),
    )

    EditEntryCancelled -> #(
      reset_edit_entry_draft(model),
      editor_dialog.close_edit_entry_dialog(),
    )

    EditEntrySubmitted -> {
      case rename_selected_file(model) {
        option.Some(next_model) ->
          #(next_model, editor_dialog.close_edit_entry_dialog())

        option.None ->
          #(model, effect.none())
      }
    }

    EditEntryDeleted -> {
      case delete_selected_entry(model) {
        option.Some(next_model) ->
          #(next_model, editor_dialog.close_edit_entry_dialog())

        option.None ->
          #(model, effect.none())
      }
    }

    EditEntryDialogClosed -> #(
      reset_edit_entry_draft(model),
      editor_dialog.focus_editor(),
    )

    TabSelected(tab) -> #(
      RealModel(
        ..model,
        selected_tab: tab,
        edit_entry_filename: default_file_name(model.files, tab),
      ),
      effect.none(),
    )

    SourceCodeChanged(source_code) -> #(
      update_selected_tab_content(model, source_code),
      effect.none(),
    )

    RunSubmitted -> {
      let request =
        run.RunRequest(
          image: language.container_image(model.language),
          payload: run.RunRequestPayload(
            run_instructions: language.run_instructions(
              model.language,
              language.default_filename(model.language),
              [],
            ),
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

    SaveSubmitted -> {
      let run_instructions =
        language.run_instructions(
          model.language,
          language.default_filename(model.language),
          [],
        )

      let request =
        snippet_dto.CreateSnippetRequest(
          data: snippet_dto.SnippetData(
            title: model.title,
            language: model.language,
            visibility: snippet_model.Unlisted,
            stdin: stdin_to_string(model.stdin),
            run_command: run_instructions.run_command,
            files: model.files,
          ),
        )

      let effect = case model.slug {
        option.Some(slug) ->
          api.update_snippet(
            snippet_dto.UpdateSnippetRequest(slug: slug, data: request.data),
            SaveFinished,
          )

        option.None ->
          api.create_snippet(request, SaveFinished)
      }

      #(RealModel(..model, save_state: Saving), effect)
    }

    SaveFinished(result) -> {
      case result {
        api.ApiSuccess(response) -> {
          let next_model = RealModel(..model, save_state: Saved(response.slug))
          case model.slug {
            option.Some(_) -> #(next_model, effect.none())
            option.None -> {
              let navigate =
                modem.push(
                  route.to_string(route.Snippet(response.slug)),
                  option.None,
                  option.None,
                )
              #(next_model, navigate)
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
              <> api_action.to_string(api_action.CreateSnippetAction)
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
    LoadingSnippet(_slug) ->
      html.div([], [html.text("Loading snippet...")])
    LoadError(message) ->
      html.div([], [html.text(message)])
    SupportedLanguage(model) -> view_helper(model, current_user_id)
  }
}

fn view_helper(model: RealModel, current_user_id: option.Option(Uuid)) -> Element(Msg) {
  let can_save = can_save(model, current_user_id)

  html.div([attribute.class("editor-page")], [
    html.div([attribute.class("editor-page__screen-glow")], []),
    html.header([attribute.class("editor-page__topbar")], [
      html.div([attribute.class("editor-page__title-group")], [
        icon_button("editor-page__icon-button editor-page__icon-button--menu", [
          html.span([attribute.class("editor-page__menu-icon")], []),
        ]),
        html.span([attribute.class("editor-page__brand")], [
          html.text("glot.io"),
        ]),
      ]),
      html.div([attribute.class("editor-page__status")], [
        html.span([attribute.class("editor-page__status-pill")], [
          html.text(string.uppercase(language.to_string(model.language))),
        ]),
      ]),
    ]),
    html.main([attribute.class("editor-shell")], [
      html.div([attribute.class("editor-shell__bezel")], [
        html.h1([attribute.class("editor-page__title")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.class("editor-page__title-button"),
              attribute.attribute("aria-label", "Edit title"),
              event.on_click(TitleClicked),
            ],
            [
              html.span([attribute.class("editor-page__title-text")], [
                html.text(model.title),
              ]),
              html.span([attribute.class("editor-page__title-hint")], [
                html.text("Edit"),
              ]),
            ],
          ),
        ]),
      ]),
      title_dialog_view(model),
      add_entry_dialog_view(model),
      edit_entry_dialog_view(model),
      html.div([attribute.class("editor-shell__tabbar")], tabbar_children(model)),
      html.div([attribute.class("editor-shell__editor")], [
        element.element(
          "glot-codemirror",
          [
            attribute.id(editor_dialog.editor_id),
            attribute.class("editor-shell__codemirror"),
            attribute.attribute("language", language.to_string(model.language)),
            attribute.attribute("value", selected_tab_content(model)),
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
          model.save_state == Saving || !can_save,
          SaveSubmitted,
        ),
      ]),
      console_view(model.run_state, model.save_state),
    ]),
  ])
}

fn icon_button(class_name: String, children: List(Element(msg))) -> Element(msg) {
  html.button(
    [attribute.type_("button"), attribute.class(class_name)],
    children,
  )
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
      attribute.id(editor_dialog.title_dialog_id),
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
                attribute.class("editor-page__dialog-button editor-page__dialog-button--secondary"),
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
      attribute.id(editor_dialog.add_entry_dialog_id),
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
            toggle_button("File", model.add_entry_kind == AddFileEntry, AddFileEntry),
            toggle_button("stdin", model.add_entry_kind == AddStdinEntry, AddStdinEntry),
          ]),
          add_entry_fields_view(model),
          html.div([attribute.class("editor-page__dialog-actions")], [
            html.button(
              [
                attribute.type_("button"),
                attribute.class("editor-page__dialog-button editor-page__dialog-button--secondary"),
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
      attribute.id(editor_dialog.edit_entry_dialog_id),
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
            attribute.class("editor-page__dialog-button editor-page__dialog-button--danger"),
            event.on_click(EditEntryDeleted),
          ],
          [html.text("Delete <stdin>")],
        ),
        html.button(
          [
            attribute.type_("button"),
            attribute.class("editor-page__dialog-button editor-page__dialog-button--secondary"),
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
          attribute.class("editor-page__dialog-button editor-page__dialog-button--danger"),
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
        attribute.class("editor-page__dialog-button editor-page__dialog-button--secondary"),
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
    True ->
      "editor-page__dialog-toggle editor-page__dialog-toggle--selected"
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

fn tabbar_children(model: RealModel) -> List(Element(Msg)) {
  [
    icon_button("editor-shell__settings-button", [
      icons.gear_icon(),
    ]),
    ..list.append(
      tab_views(model),
      [
        selected_tab_action_button(model),
        icon_action_button("editor-shell__tab-action-button", AddEntryClicked, [
          icons.document_plus(),
        ]),
      ],
    ),
  ]
}

fn tab_views(model: RealModel) -> List(Element(Msg)) {
  let file_tabs = file_tab_views(model.files, model.selected_tab, 0)
  case model.stdin {
    option.Some(_) ->
      list.append(
        file_tabs,
        [tab_button("<stdin>", StdinTab, model.selected_tab == StdinTab)],
      )

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
      tab_button(name, FileTab(index), selected_tab == FileTab(index)),
      ..file_tab_views(rest, selected_tab, index + 1),
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
      attribute.attribute("aria-label", selected_tab_action_label(model.selected_tab)),
      event.on_click(SelectedTabActionClicked),
    ],
    [
      html.span([attribute.class("editor-shell__tab-meta-pill")], [
        html.text("Edit"),
      ]),
    ],
  )
}

fn can_save(model: RealModel, current_user_id: option.Option(Uuid)) -> Bool {
  case current_user_id {
    option.None -> False
    option.Some(user_id) ->
      case model.slug {
        option.None -> True
        option.Some(_) -> model.owner_user_id == option.Some(user_id)
      }
  }
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

fn console_view(run_state: RunState, save_state: SaveState) -> Element(Msg) {
  html.div([attribute.class("editor-shell__console")], [
    console_header_view(run_state, save_state),
    html.div([attribute.class("editor-shell__console-body")], [
      console_content(run_state, save_state),
    ]),
  ])
}

fn console_header_view(run_state: RunState, save_state: SaveState) -> Element(Msg) {
  case save_state, run_state {
    SaveIdle, Completed(Ok(_)) -> html.div([], [])
    _, _ ->
      html.div([attribute.class("editor-shell__console-header")], [
        html.text("INFO"),
      ])
  }
}

fn console_content(run_state: RunState, save_state: SaveState) -> Element(Msg) {
  case save_state {
    SaveError(message) ->
      console_block("SAVE FAILED", message)

    Saving ->
      console_block("", "Saving snippet...")

    Saved(slug) ->
      console_block("", "Saved snippet: " <> slug)

    SaveIdle ->
      run_console_content(run_state)
  }
}

fn run_console_content(run_state: RunState) -> Element(Msg) {
  case run_state {
    Idle ->
      console_block("", "READY.")

    Running ->
      console_block("", "Running snippet...")

    RequestError(message) ->
      console_block("RUN FAILED", message)

    Completed(result) ->
      case result {
        Ok(success) ->
          successful_run_console(success)

        Error(failure) ->
          console_block("RUN FAILED", failure.message)
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
      html.div([attribute.class("editor-shell__console-label")], [html.text(label)])
  }

  html.div([attribute.class("editor-shell__console-section")], [
    label_view,
    html.pre([attribute.class("editor-shell__console-pre")], [html.text(content)]),
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
      html.pre([attribute.class("editor-shell__result-pre")], [html.text(content)]),
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
    "stdout" -> "editor-shell__result-header editor-shell__result-header--stdout"
    "stderr" -> "editor-shell__result-header editor-shell__result-header--stderr"
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
  case filename == "" || file_name_exists(model.files, filename) {
    True -> option.None
    False -> {
      let next_index = list.length(model.files)
      let next_file = snippet_model.File(name: filename, content: "")
      option.Some(RealModel(
        ..model,
        files: list.append(model.files, [next_file]),
        selected_tab: FileTab(next_index),
        add_entry_filename: "",
      ))
    }
  }
}

fn add_stdin_entry(model: RealModel) -> option.Option(RealModel) {
  case model.stdin {
    option.Some(_) -> option.None
    option.None ->
      option.Some(RealModel(
        ..model,
        stdin: option.Some(""),
        selected_tab: StdinTab,
        add_entry_filename: "",
      ))
  }
}

fn can_submit_add_entry(model: RealModel) -> Bool {
  case model.add_entry_kind {
    AddFileEntry -> {
      let filename = string.trim(model.add_entry_filename)
      filename != "" && !file_name_exists(model.files, filename)
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
      filename != "" && !file_name_exists_except(model.files, filename, index)
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
      case filename == "" || file_name_exists_except(model.files, filename, index) {
        True -> option.None
        False ->
          option.Some(RealModel(
            ..model,
            files: rename_file_at(model.files, index, filename),
          ))
      }
    }
  }
}

fn delete_selected_entry(model: RealModel) -> option.Option(RealModel) {
  case model.selected_tab {
    StdinTab ->
      option.Some(RealModel(
        ..model,
        stdin: option.None,
        selected_tab: FileTab(0),
        edit_entry_filename: default_file_name(model.files, FileTab(0)),
      ))

    FileTab(index) ->
      case list.length(model.files) > 1 {
        False -> option.None
        True -> {
          let next_files = remove_file_at(model.files, index)
          let next_tab =
            case index >= list.length(next_files) {
              True -> FileTab(list.length(next_files) - 1)
              False -> FileTab(index)
            }

          option.Some(RealModel(
            ..model,
            files: next_files,
            selected_tab: next_tab,
            edit_entry_filename: default_file_name(next_files, next_tab),
          ))
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
      name == filename || file_name_exists_except(rest, filename, skip_index - 1)
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
      RealModel(..model, files: update_file_content_at(model.files, index, content))
    StdinTab ->
      RealModel(..model, stdin: option.Some(content))
  }
}

fn update_file_content_at(
  files: List(snippet_model.File),
  index: Int,
  content: String,
) -> List(snippet_model.File) {
  case files, index {
    [snippet_model.File(name:, ..), ..rest], 0 ->
      [snippet_model.File(name: name, content: content), ..rest]

    [first, ..rest], _ ->
      [first, ..update_file_content_at(rest, index - 1, content)]

    [], _ -> []
  }
}

fn rename_file_at(
  files: List(snippet_model.File),
  index: Int,
  filename: String,
) -> List(snippet_model.File) {
  case files, index {
    [snippet_model.File(content:, ..), ..rest], 0 ->
      [snippet_model.File(name: filename, content: content), ..rest]

    [first, ..rest], _ ->
      [first, ..rename_file_at(rest, index - 1, filename)]

    [], _ -> []
  }
}

fn remove_file_at(files: List(snippet_model.File), index: Int) -> List(snippet_model.File) {
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

fn selected_tab_action_label(tab: EditorTab) -> String {
  case tab {
    FileTab(_) -> "Edit selected file"
    StdinTab -> "Manage stdin tab"
  }
}
