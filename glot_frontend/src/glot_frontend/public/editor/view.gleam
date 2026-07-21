import gleam/dynamic/decode
import gleam/int
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/language
import glot_frontend/public/editor/execution
import glot_frontend/public/editor/file_dialog_view
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{
  type Msg, EditMetadataClicked, RunSubmitted, SaveClicked, SnippetInfoClicked,
  SourceCodeChanged,
}
import glot_frontend/public/editor/metadata_dialog_view
import glot_frontend/public/editor/model.{
  type Model, type RealModel, Initializing, LoadError, LoadingSnippet,
  SupportedLanguage, UnsupportedLanguage,
}
import glot_frontend/public/editor/policy
import glot_frontend/public/editor/restore_draft_view
import glot_frontend/public/editor/save_dialog_view
import glot_frontend/public/editor/settings as editor_settings
import glot_frontend/public/editor/settings_dialog_view
import glot_frontend/public/editor/snippet_info_view
import glot_frontend/public/editor/workspace_view
import glot_frontend/ui/delayed_loading
import glot_web/page/editor_layout
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid.{type Uuid}

pub fn view(
  model: Model,
  current_user_id: option.Option(Uuid),
  now: Timestamp,
) -> Element(Msg) {
  case model {
    Initializing(_) -> element.none()
    UnsupportedLanguage(lang) ->
      html.div([], [html.text("Unsupported language: " <> lang)])
    LoadingSnippet(_, _, loading_indicator) ->
      loading_snippet_view(delayed_loading.is_visible(loading_indicator))
    LoadError(message) -> html.div([], [html.text(message)])
    SupportedLanguage(model) -> view_helper(model, current_user_id, now)
  }
}

fn loading_snippet_view(show_loading: Bool) -> Element(msg) {
  case show_loading {
    False -> element.none()
    True ->
      html.div([attribute.class("app-page")], [
        html.div([attribute.class("app-page__screen-glow")], []),
        html.main(
          [
            attribute.id("main-content"),
            attribute.attribute("tabindex", "-1"),
            attribute.class("app-shell app-shell--narrow"),
          ],
          [
            html.section([attribute.class("app-panel")], [
              html.p(
                [
                  attribute.class("editor-page__loading"),
                  attribute.attribute("role", "status"),
                ],
                [html.text("Loading snippet...")],
              ),
            ]),
          ],
        ),
      ])
  }
}

fn view_helper(
  model: RealModel,
  current_user_id: option.Option(Uuid),
  now: Timestamp,
) -> Element(Msg) {
  let can_edit_title =
    model.slug == option.None || policy.is_owner(model, current_user_id)
  let show_snippet_info = model.slug != option.None

  editor_layout.shell(
    load_ad: True,
    title: model.title,
    title_actions: [
      case show_snippet_info {
        True ->
          editor_layout.title_hint_button(
            class_name: "editor-page__title-edit-button editor-page__title-info-button",
            aria_label: "Snippet info",
            hint_class: "editor-page__title-hint editor-page__title-hint--info",
            hint_label: "Info",
            attributes: [event.on_click(SnippetInfoClicked)],
          )

        False -> html.div([], [])
      },
      case can_edit_title {
        True ->
          editor_layout.title_hint_button(
            class_name: "editor-page__title-edit-button",
            aria_label: "Edit snippet metadata",
            hint_class: "editor-page__title-hint",
            hint_label: "Edit",
            attributes: [event.on_click(EditMetadataClicked)],
          )

        False -> html.div([], [])
      },
    ],
    pre_tabbar_children: [
      metadata_dialog_view.view(model),
      file_dialog_view.add_dialog(model),
      file_dialog_view.edit_dialog(model),
      settings_dialog_view.view(model),
      save_dialog_view.view(model, current_user_id),
      restore_draft_view.view(model, now),
      snippet_info_view.dialog(model),
    ],
    tabbar_children: workspace_view.tabbar_children(model),
    editor: element.element(
      "glot-codemirror",
      [
        attribute.id(ids.editor),
        attribute.class("editor-shell__codemirror"),
        attribute.attribute("language", language.to_string(model.language)),
        attribute.attribute(
          "editor-external-revision",
          int.to_string(model.editor_external_revision),
        ),
        attribute.attribute(
          "editor-revision",
          int.to_string(model.editor_revision),
        ),
        attribute.attribute("value", workspace_view.selected_tab_content(model)),
        attribute.attribute(
          "keyboard-bindings",
          model.editor_settings.keyboard_bindings
            |> editor_settings.keyboard_bindings_to_string(),
        ),
        event.on("change", {
          use value <- decode.subfield(["detail", "value"], decode.string)
          use revision <- decode.subfield(["detail", "revision"], decode.int)
          decode.success(SourceCodeChanged(value, revision))
        }),
        event.on("editor-run", decode.success(RunSubmitted)),
      ],
      [],
    ),
    action_buttons: [
      action_button(
        "editor-shell__action-button",
        workspace_view.run_button_text(model.run_state),
        model.run_state == execution.Running,
        RunSubmitted,
      ),
      action_button(
        "editor-shell__action-button",
        workspace_view.save_button_text(model.save_state),
        model.save_state == execution.Saving,
        SaveClicked,
      ),
    ],
    console: execution.view(
      model.version_info,
      model.run_state,
      model.save_state,
    ),
  )
}

fn action_button(
  class_name: String,
  label: String,
  disabled: Bool,
  msg: Msg,
) -> Element(Msg) {
  editor_layout.shell_button(
    class_name: class_name,
    attributes: [attribute.disabled(disabled), event.on_click(msg)],
    children: [html.text(label)],
  )
}
