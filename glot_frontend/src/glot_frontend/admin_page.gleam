import glot_core/route
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model
}

pub type Msg {
  NoOp
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(Model, effect.none())
}

pub fn update(model: Model, _msg: Msg) -> #(Model, Effect(Msg)) {
  #(model, effect.none())
}

pub fn view(_model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Admin"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text("Administrative tools and configuration."),
            ]),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Configuration"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Runtime settings are organized into dedicated pages so more sections can be added cleanly.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-page__section-grid")], [
            link_card(
              title: "App config",
              description: "Manage docker run settings and future runtime configuration sections.",
              target: route.AdminConfig,
            ),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Tools"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Dedicated admin workflows that do not fit the shared config page.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-page__section-grid")], [
            link_card(
              title: "API logs",
              description: "Review retained API request logging by request ID.",
              target: route.AdminApiLogs,
            ),
            link_card(
              title: "Job logs",
              description: "Scan operational job log output separately from the primary jobs queue view.",
              target: route.AdminJobLogs,
            ),
            link_card(
              title: "Rate limits",
              description: "Review and update API rate limit policies.",
              target: route.AdminRateLimits,
            ),
            link_card(
              title: "Jobs",
              description: "Inspect the execution queue and iterate on the admin jobs workflow.",
              target: route.AdminJobs,
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn link_card(
  title title: String,
  description description: String,
  target target: route.Route,
) -> Element(Msg) {
  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text(title),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(description),
          ]),
        ]),
        html.a(
          [
            attribute.class("admin-page__button admin-page__button--secondary"),
            route.href(target),
          ],
          [html.text("Open")],
        ),
      ]),
    ],
  )
}
