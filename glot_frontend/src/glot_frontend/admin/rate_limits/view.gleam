import gleam/list
import glot_core/loadable
import glot_frontend/admin/rate_limits/message.{type Msg, EditClicked}
import glot_frontend/admin/rate_limits/model.{
  type LimitFields, type Model, type PolicyEditor, type PolicyTabs,
}
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/admin/ui/status as admin_status
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import glot_frontend/admin/rate_limits/editor_view

pub fn view(model: Model) -> Element(Msg) {
  html.div([], [
    admin_layout.page(
      title: "Admin rate limits",
      intro: "Each action shows its current limits. Edit opens a compact modal.",
      content: [status_banner(model.policies), policies_view(model)],
    ),
    editor_view.view(model),
  ])
}

fn status_banner(state: loadable.Loadable(List(PolicyEditor))) -> Element(Msg) {
  loadable.fold(
    state,
    html.div([], []),
    admin_status.status("Loading policies..."),
    fn(_) { html.div([], []) },
    admin_status.error_status,
  )
}

fn policies_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.policies,
    html.div([], []),
    html.div([], []),
    fn(policies) {
      html.div(
        [attribute.class("admin-page__policies")],
        list.map(policies, policy_summary_view),
      )
    },
    fn(_) { html.div([], []) },
  )
}

fn policy_summary_view(policy: PolicyEditor) -> Element(Msg) {
  html.article([attribute.class("admin-page__policy")], [
    html.div([attribute.class("admin-page__policy-header")], [
      html.div([], [
        html.h3([attribute.class("admin-page__policy-title")], [
          html.text(editor_view.action_label(policy.action)),
        ]),
      ]),
      html.div([attribute.class("admin-page__policy-header-actions")], [
        admin_layout.secondary_button(
          [
            attribute.type_("button"),
            event.on_click(EditClicked(policy.action)),
          ],
          "Edit",
        ),
      ]),
    ]),
    summary_rows(policy.saved_tabs),
  ])
}

fn summary_rows(tabs: PolicyTabs) -> Element(Msg) {
  case editor_view.tabs_is_empty(tabs) {
    True ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No limits"),
      ])
    False ->
      html.div([attribute.class("admin-page__summary")], [
        html.div(
          [
            attribute.class(
              "admin-page__summary-row admin-page__summary-row--head",
            ),
          ],
          [
            html.span([attribute.class("admin-page__summary-label")], [
              html.text("Tier"),
            ]),
            html.span([attribute.class("admin-page__summary-unit")], [
              html.text("Second"),
            ]),
            html.span([attribute.class("admin-page__summary-unit")], [
              html.text("Minute"),
            ]),
            html.span([attribute.class("admin-page__summary-unit")], [
              html.text("Hour"),
            ]),
            html.span([attribute.class("admin-page__summary-unit")], [
              html.text("Day"),
            ]),
          ],
        ),
        summary_row("Anonymous", tabs.anonymous),
        summary_row("Free", tabs.free),
        summary_row("FreePlus", tabs.free_plus),
      ])
  }
}

fn summary_row(label: String, fields: LimitFields) -> Element(Msg) {
  html.div([attribute.class("admin-page__summary-row")], [
    html.span([attribute.class("admin-page__summary-label")], [
      html.text(label),
    ]),
    summary_value(fields.second),
    summary_value(fields.minute),
    summary_value(fields.hour),
    summary_value(fields.day),
  ])
}

fn summary_value(value: String) -> Element(Msg) {
  html.span([attribute.class("admin-page__summary-value")], [
    html.text(case value {
      "" -> "-"
      _ -> value
    }),
  ])
}
