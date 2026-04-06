import gleam/option
import glot_core/language
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model(language: Lang)
}

pub type Lang {
  SupportedLanguage(language.Language)
  UnsupportedLanguage(String)
}

pub fn init(language: String) -> #(Model, Effect(Msg)) {
  let lang =
    language.from_string(language)
    |> option.map(SupportedLanguage)
    |> option.unwrap(UnsupportedLanguage(language))

  let model = Model(language: lang)

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
  case model.language {
    SupportedLanguage(lang) -> view_helper(model, lang)
    UnsupportedLanguage(lang) ->
      html.div([], [html.text("Unsupported language: " <> lang)])
  }
}

pub fn view_helper(model: Model, lang: language.Language) -> Element(Msg) {
  html.div([], [
    html.h2([], [html.text("New Snippet: " <> language.name(lang))]),
    html.div([], [
      element.element(
        "glot-codemirror",
        [attribute.attribute("language", language.to_string(lang))],
        [],
      ),
    ]),
  ])
}
