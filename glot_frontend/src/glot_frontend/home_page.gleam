import glot_frontend/route
import glot_frontend/top_bar
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model
}

pub fn init() -> #(Model, Effect(Msg)) {
  let model = Model

  #(model, effect.none())
}

pub type Msg {
  Increment
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Increment -> {
      #(model, effect.none())
    }
  }
}

pub fn view(_model: Model, current_user_label: String) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    top_bar.view(current_user_label),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel home-page__content")], [
        html.h2([attribute.class("home-page__title")], [html.text("Home")]),
        html.a([
          attribute.class("home-page__link"),
          route.href(route.NewSnippet("python")),
        ], [
          html.text("Python"),
        ]),
      ]),
    ]),
  ])
}
