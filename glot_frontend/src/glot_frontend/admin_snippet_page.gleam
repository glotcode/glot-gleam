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
import glot_frontend/api
import glot_frontend/app_dialog
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
    snippet: option.Option(snippet_dto.SnippetDetailResponse),
    pending_delete: option.Option(snippet_dto.SnippetDetailResponse),
    status: Status,
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  Deleting
  LoadError(String)
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
      snippet: option.None,
      pending_delete: option.None,
      status: NotLoaded,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      api.get_admin_snippet(
        snippet_dto.GetSnippetRequest(slug: model.slug),
        SnippetLoaded,
      ),
    )
    Loading | Ready | Deleting | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SnippetLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            snippet: option.Some(response.snippet),
            pending_delete: option.None,
            status: Ready,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, pending_delete: option.None, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            pending_delete: option.None,
            status: LoadError("Could not load snippet."),
          ),
          effect.none(),
        )
      }

    DeleteClicked ->
      case model.snippet {
        option.Some(snippet) -> #(
          Model(..model, pending_delete: option.Some(snippet)),
          app_dialog.open(delete_dialog_id),
        )
        option.None -> #(model, effect.none())
      }

    DeleteCancelled -> #(model, app_dialog.close(delete_dialog_id))

    DeleteDialogClosed ->
      #(Model(..model, pending_delete: option.None), effect.none())

    DeleteConfirmed ->
      case model.pending_delete {
        option.Some(snippet) -> #(
          Model(..model, status: Deleting),
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
        api.ApiSuccess(_) ->
          #(
            Model(..model, pending_delete: option.None, status: Ready),
            navigate_to_snippets(),
          )
        api.ApiFailure(error) ->
          #(
            Model(
              ..model,
              pending_delete: option.None,
              status: LoadError(error.message),
            ),
            effect.none(),
          )
        api.HttpFailure(_) ->
          #(
            Model(
              ..model,
              pending_delete: option.None,
              status: LoadError("Could not delete snippet."),
            ),
            effect.none(),
          )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page admin-job-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Snippet detail"),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-actions")], [
            html.a(
              [
                attribute.class(
                  "admin-page__button admin-page__button--secondary",
                ),
                route.href(route.Snippet(model.slug)),
              ],
              [html.text("Open public snippet")],
            ),
            html.button(
              [
                attribute.type_("button"),
                attribute.class("admin-page__button admin-page__button--danger"),
                attribute.disabled(model.status == Deleting),
                event.on_click(DeleteClicked),
              ],
              [
                html.text(case model.status {
                  Deleting -> "Deleting..."
                  NotLoaded | Loading | Ready | LoadError(_) -> "Delete snippet"
                }),
              ],
            ),
          ]),
        ]),
        status_view(model),
        detail_view(model),
      ]),
    ]),
    delete_confirmation_dialog(model),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [html.text("")])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading snippet..."),
      ])
    Deleting ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Deleting snippet..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  case model.snippet, model.status {
    option.None, Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading snippet..."),
      ])
    option.None, _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("This snippet could not be loaded."),
      ])
    option.Some(snippet), _ ->
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class("admin-job-page__summary-grid")], [
          summary_card("Title", snippet.title),
          summary_card("Owner", snippet.user.username),
          summary_card("Language", language.name(snippet.language)),
          summary_card("Visibility", visibility_text(snippet.visibility)),
          summary_card("Slug", snippet.slug),
          summary_card("Files", int.to_string(list.length(snippet.files))),
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
          html.div([attribute.class("admin-job-page__detail-grid")], [
            detail_item("Snippet ID", uuid.to_string(snippet.id)),
            detail_item("Slug", snippet.slug),
            detail_item("Owner", snippet.user.username),
            detail_item("Owner ID", uuid.to_string(snippet.user.id)),
            detail_item("Language", language.name(snippet.language)),
            detail_item("Visibility", visibility_text(snippet.visibility)),
            detail_item("Created at", format_timestamp(snippet.created_at)),
            detail_item("Updated at", format_timestamp(snippet.updated_at)),
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
          html.div([attribute.class("admin-job-page__detail-grid")], [
            detail_item(
              "Run command",
              optional_run_command(snippet.run_instructions),
            ),
            detail_item(
              "Build commands",
              build_commands_text(snippet.run_instructions),
            ),
          ]),
          html.div([attribute.class("admin-page__policy")], [
            html.span([attribute.class("admin-job-page__eyebrow")], [
              html.text("stdin"),
            ]),
            html.pre([attribute.class("admin-job-page__code-block")], [
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
  }
}

fn file_view(file: snippet_model.File) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy admin-snippet-page__file")], [
    html.div([attribute.class("admin-snippet-page__file-header")], [
      html.span([attribute.class("admin-job-page__eyebrow")], [
        html.text("File"),
      ]),
      html.strong([attribute.class("admin-snippet-page__file-name")], [
        html.text(file.name),
      ]),
    ]),
    html.pre([attribute.class("admin-job-page__code-block")], [
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

fn summary_card(title: String, value: String) -> Element(Msg) {
  html.article(
    [attribute.class("admin-page__policy admin-job-page__summary-card")],
    [
      html.span([attribute.class("admin-job-page__eyebrow")], [html.text(title)]),
      html.strong([attribute.class("admin-job-page__summary-value")], [
        html.text(value),
      ]),
    ],
  )
}

fn detail_item(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy admin-job-page__detail-item")], [
    html.span([attribute.class("admin-job-page__eyebrow")], [html.text(label)]),
    html.span([attribute.class("admin-job-page__detail-value")], [
      html.text(value),
    ]),
  ])
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
