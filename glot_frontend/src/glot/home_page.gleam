import glot/route
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

pub fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.h2([], [html.text("Home")]),
    html.a([route.href(route.NewSnippet("python"))], [
      html.text("Python"),
    ]),
  ])
}
