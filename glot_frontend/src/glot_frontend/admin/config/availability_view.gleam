import gleam/option
import glot_core/availability_mode
import glot_frontend/admin/config/section
import glot_frontend/admin/ui/form as admin_form
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/ui/mutation
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import glot_frontend/admin/config/availability.{
  type Model, type Msg, MessageChanged, ModeSelected, ResetClicked,
  RetryAfterSecondsChanged, SaveClicked,
}
import glot_frontend/admin/config/section_view

pub fn view(model: Model) -> Element(Msg) {
  let dirty = section.is_dirty(model)
  section_view.card(
    title: "Availability",
    subtitle: "Controls whether the app is normal, read-only, or unavailable to non-admin traffic.",
    state: model.mutation_state,
    dirty:,
    idle_badge: option.None,
    fields: html.div([attribute.class("admin-page__field-grid")], [
      html.div([attribute.class("admin-page__field")], [
        html.span([attribute.class("admin-page__field-label")], [
          html.text("Mode"),
        ]),
        html.div([attribute.class("admin-page__actions")], [
          mode_button("Normal", availability_mode.NormalMode, model),
          mode_button("Read only", availability_mode.ReadOnlyMode, model),
          mode_button("Maintenance", availability_mode.MaintenanceMode, model),
        ]),
        html.span([attribute.class("admin-page__field-help")], [
          html.text(
            "Admin routes and admin actions remain available. Read-only blocks writes. Maintenance blocks most public traffic.",
          ),
        ]),
      ]),
      admin_form.textarea_input(
        label: "Message",
        help: "Shown in 503 responses for unavailable pages and APIs.",
        value: model.draft.message,
        rows: 3,
        on_input: MessageChanged,
      ),
      admin_form.text_input(
        label: "Retry-After seconds",
        help: "Optional integer. Leave blank to omit the Retry-After header.",
        value: model.draft.retry_after_seconds,
        placeholder: "300",
        on_input: RetryAfterSecondsChanged,
      ),
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

fn mode_button(
  label: String,
  mode: availability_mode.AvailabilityMode,
  model: Model,
) -> Element(Msg) {
  let class_name = case model.draft.mode == mode {
    True -> admin_layout.primary_button_class()
    False -> admin_layout.secondary_button_class()
  }
  html.button(
    [
      attribute.type_("button"),
      attribute.class(class_name),
      attribute.disabled(
        !section.is_ready(model.load_state)
        || mutation.is_saving(model.mutation_state),
      ),
      event.on_click(ModeSelected(mode)),
    ],
    [html.text(label)],
  )
}
