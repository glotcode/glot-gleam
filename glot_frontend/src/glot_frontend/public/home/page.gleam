import glot_web/page/home
import lustre/effect.{type Effect}
import lustre/element.{type Element}

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

pub fn view(_model: Model) -> Element(Msg) {
  home.view(load_ad: True)
}
