import gleam/int
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", 0)

  Nil
}

type Model {
  Model(count: Int)
}

fn init(count: Int) -> #(Model, Effect(Msg)) {
  let model = Model(count: count)

  #(model, effect.none())
}

type Msg {
  Increment
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Increment -> #(Model(count: model.count + 1), effect.none())
  }
}

fn view(model: Model) -> Element(Msg) {
  html.div([], [
    html.h1([], [html.text("count: " <> int.to_string(model.count))]),
    element.element("glot-codemirror", [], []),
  ])
}
