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

pub fn view() -> Element(Msg) {
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
        html.div([attribute.class("admin-page__policies")], [
          html.article([attribute.class("admin-page__policy")], [
            html.div([attribute.class("admin-page__policy-header")], [
              html.div([], [
                html.h3([attribute.class("admin-page__policy-title")], [
                  html.text("Rate limits"),
                ]),
                html.p([attribute.class("admin-page__status")], [
                  html.text("Review and update API rate limit policies."),
                ]),
              ]),
              html.a(
                [
                  attribute.class(
                    "admin-page__button admin-page__button--secondary",
                  ),
                  route.href(route.AdminRateLimits),
                ],
                [html.text("Open")],
              ),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
}
