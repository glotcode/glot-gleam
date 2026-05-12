import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/snippet_dto
import glot_core/language
import glot_core/route
import glot_core/snippet/snippet_dto as public_snippet_dto
import glot_core/snippet/snippet_model
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/app_dialog
import glot_frontend/loadable
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import youid/uuid

const delete_dialog_id = "admin-snippet-page-delete-dialog"

pub type Model {
  Model(
    slug: String,
    snippet: loadable.Loadable(snippet_dto.SnippetDetailResponse),
    pending_delete: option.Option(snippet_dto.SnippetDetailResponse),
    delete_state: DeleteState,
  )
}

pub type DeleteState {
  DeleteIdle
  Deleting
}

pub type Msg {
  SnippetLoaded(api.ApiResponse(snippet_dto.GetSnippetResponse))
  DeleteClicked
  DeleteCancelled
  DeleteDialogClosed
  DeleteConfirmed
  DeleteFinished(api.ApiResponse(Nil))
}

pub fn init(slug: String) -> #(Model, Effect(Msg)) {
  #(
    Model(
      slug: slug,
      snippet: loadable.NotLoaded,
      pending_delete: option.None,
      delete_state: DeleteIdle,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case loadable.ensure_loaded(
    model.snippet,
    api.get_admin_snippet(
      snippet_dto.GetSnippetRequest(slug: model.slug),
      SnippetLoaded,
    ),
  ) {
    #(snippet, next_effect) -> #(Model(..model, snippet: snippet), next_effect)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SnippetLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            snippet: loadable.Loaded(response.snippet),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            snippet: loadable.LoadError(error.message),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            snippet: loadable.LoadError("Could not load snippet."),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
      }

    DeleteClicked ->
      case model.snippet {
        loadable.Loaded(snippet) -> #(
          Model(..model, pending_delete: option.Some(snippet)),
          app_dialog.open(delete_dialog_id),
        )
        _ -> #(model, effect.none())
      }

    DeleteCancelled -> #(model, app_dialog.close(delete_dialog_id))

    DeleteDialogClosed -> #(
      Model(..model, pending_delete: option.None),
      effect.none(),
    )

    DeleteConfirmed ->
      case model.pending_delete {
        option.Some(snippet) -> #(
          Model(..model, delete_state: Deleting),
          effect.batch([
            app_dialog.close(delete_dialog_id),
            api.delete_admin_snippet(
              public_snippet_dto.DeleteSnippetRequest(slug: snippet.slug),
              DeleteFinished,
            ),
          ]),
        )
        option.None -> #(model, effect.none())
      }

    DeleteFinished(result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(..model, pending_delete: option.None, delete_state: DeleteIdle),
          navigate_to_snippets(),
        )
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            snippet: loadable.LoadError(error.message),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            snippet: loadable.LoadError("Could not delete snippet."),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([], [
    admin_ui.page_with_panel_class(
      panel_class: "admin-job-page",
      title: "Snippet detail",
      intro: "",
      actions: [
        admin_ui.secondary_link(
          [route.href(route.Snippet(model.slug))],
          "Open public snippet",
        ),
        html.button(
          [
            attribute.type_("button"),
            attribute.class("admin-page__button admin-page__button--danger"),
            attribute.disabled(model.delete_state == Deleting),
            event.on_click(DeleteClicked),
          ],
          [
            html.text(case model.delete_state {
              Deleting -> "Deleting..."
              DeleteIdle -> "Delete snippet"
            }),
          ],
        ),
      ],
      content: [status_view(model), detail_view(model)],
    ),
    delete_confirmation_dialog(model),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.snippet, model.delete_state {
    loadable.LoadError(message), _ -> admin_ui.error_status(message)
    loadable.Loading, _ -> admin_ui.status("Loading snippet...")
    _, Deleting -> admin_ui.status("Deleting snippet...")
    _, DeleteIdle -> admin_ui.status("")
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.snippet,
    admin_ui.empty_state("This snippet could not be loaded."),
    admin_ui.empty_state("Loading snippet..."),
    fn(snippet) {
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class(admin_ui.summary_grid_class())], [
          admin_ui.summary_card("Title", snippet.title),
          admin_ui.summary_card("Owner", snippet.user.username),
          admin_ui.summary_card("Language", language.name(snippet.language)),
          admin_ui.summary_card(
            "Visibility",
            visibility_text(snippet.visibility),
          ),
          admin_ui.summary_card("Slug", snippet.slug),
          admin_ui.summary_card(
            "Files",
            int.to_string(list.length(snippet.files)),
          ),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Snippet"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Metadata is kept separate from file contents so the page can grow with future admin actions.",
              ),
            ]),
          ]),
          html.div([attribute.class(admin_ui.detail_grid_class())], [
            admin_ui.detail_item("Snippet ID", uuid.to_string(snippet.id)),
            admin_ui.detail_item("Slug", snippet.slug),
            admin_ui.detail_item("Owner", snippet.user.username),
            admin_ui.detail_item("Owner ID", uuid.to_string(snippet.user.id)),
            admin_ui.detail_item("Language", language.name(snippet.language)),
            admin_ui.detail_item(
              "Visibility",
              visibility_text(snippet.visibility),
            ),
            admin_ui.detail_item(
              "Created at",
              format_timestamp(snippet.created_at),
            ),
            admin_ui.detail_item(
              "Updated at",
              format_timestamp(snippet.updated_at),
            ),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Run configuration"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Run instructions and stdin are shown directly as stored, without editor dependencies.",
              ),
            ]),
          ]),
          html.div([attribute.class(admin_ui.detail_grid_class())], [
            admin_ui.detail_item(
              "Run command",
              optional_run_command(snippet.run_instructions),
            ),
            admin_ui.detail_item(
              "Build commands",
              build_commands_text(snippet.run_instructions),
            ),
          ]),
          html.div([attribute.class("admin-page__policy")], [
            html.span([attribute.class("admin-info-label")], [
              html.text("stdin"),
            ]),
            html.pre([attribute.class("admin-page__code-block")], [
              html.text(empty_text(snippet.stdin)),
            ]),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Files"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Each stored file is rendered as plain text for a low-maintenance admin review workflow.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-snippet-page__files")], {
            snippet.files |> list.map(file_view)
          }),
        ]),
      ])
    },
    fn(_) { admin_ui.empty_state("This snippet could not be loaded.") },
  )
}

fn file_view(file: snippet_model.File) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy admin-snippet-page__file")], [
    html.div([attribute.class("admin-snippet-page__file-header")], [
      html.span([attribute.class("admin-info-label")], [
        html.text("File"),
      ]),
      html.strong([attribute.class("admin-snippet-page__file-name")], [
        html.text(file.name),
      ]),
    ]),
    html.pre([attribute.class("admin-page__code-block")], [
      html.code([], [html.text(empty_text(file.content))]),
    ]),
  ])
}

fn delete_confirmation_dialog(model: Model) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(delete_dialog_id),
      attribute.class("app-dialog"),
      event.on("close", decode.success(DeleteDialogClosed)),
    ],
    delete_confirmation_dialog_children(model.pending_delete),
  )
}

fn delete_confirmation_dialog_children(
  pending_delete: option.Option(snippet_dto.SnippetDetailResponse),
) -> List(Element(Msg)) {
  case pending_delete {
    option.Some(snippet) -> [
      html.form([attribute.class("app-dialog__form")], [
        html.div([attribute.class("app-dialog__section")], [
          html.p([attribute.class("app-dialog__label")], [
            html.text("Delete snippet"),
          ]),
          html.p([attribute.class("app-dialog__copy")], [
            html.text("Delete "),
            html.code([], [html.text(snippet.title)]),
            html.text("? This action cannot be undone."),
          ]),
        ]),
        html.div([attribute.class("app-dialog__actions")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.autofocus(True),
              attribute.class(
                "app-dialog__button app-dialog__button--secondary",
              ),
              event.on_click(DeleteCancelled),
            ],
            [html.text("Cancel")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("app-dialog__button app-dialog__button--danger"),
              event.on_click(DeleteConfirmed),
            ],
            [html.text("Delete snippet")],
          ),
        ]),
      ]),
    ]
    option.None -> []
  }
}

fn optional_run_command(
  instructions: option.Option(language.RunInstructions),
) -> String {
  case instructions {
    option.Some(instructions) -> instructions.run_command
    option.None -> "None"
  }
}

fn build_commands_text(
  instructions: option.Option(language.RunInstructions),
) -> String {
  case instructions {
    option.Some(instructions) ->
      case instructions.build_commands {
        [] -> "None"
        commands -> string.join(commands, with: ", ")
      }
    option.None -> "None"
  }
}

fn visibility_text(visibility: snippet_model.Visibility) -> String {
  case visibility {
    snippet_model.Public -> "Public"
    snippet_model.Unlisted -> "Unlisted"
  }
}

fn empty_text(value: String) -> String {
  case value == "" {
    True -> "Empty"
    False -> value
  }
}

fn format_timestamp(value) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}

fn navigate_to_snippets() -> Effect(Msg) {
  let #(path, query) = route.path_and_query(route.AdminSnippets)
  modem.push(path, query, option.None)
}
