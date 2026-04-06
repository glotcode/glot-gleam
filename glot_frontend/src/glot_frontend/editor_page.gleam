import gleam/option
import gleam/pair
import glot_core/language
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  UnsupportedLanguage(String)
  SupportedLanguage(RealModel)
}

pub type RealModel {
  RealModel(language: language.Language)
}

pub fn init(language: String) -> #(Model, Effect(Msg)) {
  let model = case language.from_string(language) {
    option.Some(lang) -> SupportedLanguage(RealModel(language: lang))
    option.None -> UnsupportedLanguage(language)
  }

  #(model, effect.none())
}

pub type Msg {
  Increment
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model {
    UnsupportedLanguage(_) -> #(model, effect.none())
    SupportedLanguage(model) ->
      update_helper(model, msg)
      |> pair.map_first(SupportedLanguage)
  }
}

pub fn update_helper(model: RealModel, msg: Msg) -> #(RealModel, Effect(Msg)) {
  case msg {
    Increment -> {
      #(model, effect.none())
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  case model {
    UnsupportedLanguage(lang) ->
      html.div([], [html.text("Unsupported language: " <> lang)])
    SupportedLanguage(model) -> view_helper(model)
  }
}

fn view_helper(model: RealModel) -> Element(Msg) {
  html.div([], [
    html.h2([], [html.text("New Snippet: " <> language.name(model.language))]),
    html.div([], [
      element.element(
        "glot-codemirror",
        [attribute.attribute("language", language.to_string(model.language))],
        [],
      ),
    ]),
  ])
}
