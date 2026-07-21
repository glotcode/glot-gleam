import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_core/language
import glot_core/route
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{
  type Msg, SnippetInfoClosed, SnippetInfoDismissed,
}
import glot_frontend/public/editor/model.{type RealModel}
import glot_web/page/editor_layout
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

pub fn dialog(model: RealModel) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(ids.snippet_info_dialog),
      attribute.class("editor-page__dialog"),
      attribute.attribute("aria-label", "Snippet information"),
      event.on("close", decode.success(SnippetInfoClosed)),
    ],
    children(model),
  )
}

fn children(model: RealModel) -> List(Element(Msg)) {
  let common_rows = [
    info_row("Title", model.title),
    info_row("Language", language.name(model.language)),
  ]
  case model.slug {
    option.Some(_) -> [
      editor_layout.dialog_form([
        editor_layout.dialog_info_heading(),
        editor_layout.dialog_panel(
          list.append(common_rows, [
            info_row("Author", owner_label(model)),
            info_row(
              "Visibility",
              snippet_model.visibility_to_string(model.visibility)
                |> string.uppercase,
            ),
            info_row("URL", snippet_url(model)),
            info_row("Created", optional_timestamp_label(model.created_at)),
            info_row("Updated", optional_timestamp_label(model.updated_at)),
          ]),
        ),
        close_actions(),
      ]),
    ]
    option.None -> [
      editor_layout.dialog_form([
        editor_layout.dialog_info_heading(),
        editor_layout.dialog_panel(common_rows),
        html.p([attribute.class("editor-page__dialog-copy")], [
          html.text("This snippet has not been saved yet."),
        ]),
        close_actions(),
      ]),
    ]
  }
}

fn close_actions() -> Element(Msg) {
  editor_layout.dialog_actions([
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
  ])
}

fn info_row(label: String, value: String) -> Element(Msg) {
  editor_layout.dialog_info_row(label, value)
}

fn snippet_url(model: RealModel) -> String {
  case model.slug {
    option.Some(slug) ->
      "https://glot.io" <> route.to_string(route.Public(route.Snippet(slug)))
    option.None -> ""
  }
}

fn owner_label(model: RealModel) -> String {
  case model.owner_username {
    option.Some(username) -> username
    option.None ->
      model.owner_user_id
      |> option.map(uuid.to_string)
      |> option.unwrap("Unknown")
  }
}

fn optional_timestamp_label(value: option.Option(Timestamp)) -> String {
  value
  |> option.map(fn(value) { timestamp.to_rfc3339(value, calendar.utc_offset) })
  |> option.unwrap("Unknown")
}
