import gleam/list
import glot_core/language.{type Language}
import glot_core/page/icons
import glot_core/page/logo
import glot_core/route
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view() -> Element(msg) {
  html.div([attribute.class("app-page app-page--home")], [
    html.main([attribute.class("home-page")], [
      html.section([attribute.class("home-hero")], [
        html.div([attribute.class("home-hero__inner")], [
          html.div(
            [
              attribute.class("home-hero__logo"),
              attribute.attribute("role", "img"),
              attribute.attribute("aria-label", "glot.io"),
            ],
            [],
          ),
          html.p([attribute.class("home-hero__tagline")], [
            html.text("an "),
            html.a(
              [
                attribute.class("home-hero__link"),
                attribute.href("https://github.com/prasmussen/glot"),
              ],
              [html.text("open source")],
            ),
            html.text(" code playground."),
          ]),
        ]),
      ]),
      html.section([attribute.class("home-section home-features")], [
        html.h2([attribute.class("home-section__title")], [
          html.text("Features"),
        ]),
        html.div([attribute.class("home-features__grid")], [
          feature_card(
            icons.play(),
            "Run code",
            "The code is executed in a transient docker container without network.",
          ),
          feature_card(
            icons.share(),
            "Share snippets",
            "Snippets can be saved and shared with others.",
          ),
          feature_card(
            icons.cog_6_tooth(),
            "Key bindings",
            "The editor supports Vim and Emacs key bindings.",
          ),
          feature_card(
            icons.globe_alt(),
            "Open source",
            "If your favorite language is missing you can open an issue or pull request on GitHub to get it added.",
          ),
        ]),
      ]),
      html.section([attribute.class("home-section home-languages")], [
        html.h2([attribute.class("home-section__title")], [
          html.text("Select a language"),
        ]),
        html.div([attribute.class("home-languages__grid")], {
          language.list()
          |> list.map(language_card)
        }),
      ]),
    ]),
  ])
}

fn feature_card(
  icon: Element(msg),
  title: String,
  copy: String,
) -> Element(msg) {
  html.article([attribute.class("home-feature")], [
    html.div(
      [
        attribute.class("home-feature__icon"),
        attribute.attribute("aria-hidden", "true"),
      ],
      [icon],
    ),
    html.div([attribute.class("home-feature__body")], [
      html.h3([attribute.class("home-feature__title")], [html.text(title)]),
      html.p([attribute.class("home-feature__copy")], [html.text(copy)]),
    ]),
  ])
}

fn language_card(lang: Language) -> Element(msg) {
  html.a(
    [
      attribute.class("home-language"),
      route.href(route.Public(route.NewSnippet(language.to_string(lang)))),
    ],
    [
      html.span([attribute.class("home-language__logo")], [
        logo.language_logo(lang),
      ]),
      html.span([attribute.class("home-language__name")], [
        html.text(language.name(lang)),
      ]),
    ],
  )
}
