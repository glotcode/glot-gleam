import gleam/option
import glot_frontend/admin/config/section
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/ui/mutation
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import glot_frontend/admin/config/debug.{
  type Model, type Msg, ResetClicked, SaveClicked, ToggleClicked,
}
import glot_frontend/admin/config/section_view

pub fn view(model: Model) -> Element(Msg) {
  let dirty = model.draft != model.saved
  section_view.card(
    title: "Debug",
    subtitle: "Controls whether backend debug log fields are collected into API and page logs.",
    state: model.mutation_state,
    dirty:,
    idle_badge: option.None,
    fields: html.div([attribute.class("admin-page__field-grid")], [
      html.div([attribute.class("admin-page__field")], [
        html.span([attribute.class("admin-page__field-label")], [
          html.text("Debug logging"),
        ]),
        admin_layout.secondary_button(
          [
            attribute.type_("button"),
            attribute.disabled(
              !section.is_ready(model.load_state)
              || mutation.is_saving(model.mutation_state),
            ),
            event.on_click(ToggleClicked),
          ],
          case model.draft.enabled {
            True -> "Enabled"
            False -> "Disabled"
          },
        ),
        html.span([attribute.class("admin-page__field-help")], [
          html.text(
            "When enabled, debug fields are persisted with API logs. Toggle to change the draft value.",
          ),
        ]),
      ]),
    ]),
    footer: section_view.footer(
      load_state: model.load_state,
      mutation_state: model.mutation_state,
      dirty:,
      idle_message: option.None,
      reset_msg: ResetClicked,
      save_msg: SaveClicked,
    ),
  )
}
