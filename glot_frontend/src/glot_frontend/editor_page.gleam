import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model(language: String)
}

pub fn init(language: String) -> #(Model, Effect(Msg)) {
  let model = Model(language: language)

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
    html.h2([], [html.text("New Snippet: " <> model.language)]),
    html.div([], [
      element.element("glot-codemirror", [], []),
    ]),
  ])
}
