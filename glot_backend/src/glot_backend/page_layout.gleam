import gleam/list
import gleam/option
import glot_backend/page_theme.{type PageTheme}
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn document(
  title title: String,
  theme theme: option.Option(PageTheme),
  head_children head_children: List(element.Element(msg)),
  include_frontend include_frontend: Bool,
  stylesheet_href stylesheet_href: String,
  additional_stylesheet_hrefs additional_stylesheet_hrefs: List(String),
  frontend_src frontend_src: String,
  frontend_preloads frontend_preloads: List(String),
  app_attributes app_attributes: List(attribute.Attribute(msg)),
  app_children app_children: List(element.Element(msg)),
) -> String {
  let base_head =
    list.append(
      [
        html.meta([attribute.charset("utf-8")]),
        html.meta([
          attribute.name("viewport"),
          attribute.content("width=device-width, initial-scale=1"),
        ]),
        html.meta([
          attribute.name("color-scheme"),
          attribute.content("light dark"),
        ]),
        html.meta([
          attribute.name("theme-color"),
          attribute.content("#111827"),
        ]),
        html.meta([
          attribute.name("referrer"),
          attribute.content("strict-origin-when-cross-origin"),
        ]),
        html.meta([
          attribute.name("format-detection"),
          attribute.content("telephone=no"),
        ]),
        html.link([
          attribute.rel("icon"),
          attribute.type_("image/svg+xml"),
          attribute.href("/static/favicon.svg"),
        ]),
        html.link([
          attribute.rel("manifest"),
          attribute.href("/static/site.webmanifest"),
        ]),
        html.title([], title),
        html.link([
          attribute.rel("stylesheet"),
          attribute.href(stylesheet_href),
        ]),
      ],
      list.map(additional_stylesheet_hrefs, fn(href) {
        html.link([attribute.rel("stylesheet"), attribute.href(href)])
      }),
    )
  let tail_head = case include_frontend {
    True ->
      list.append(
        list.map(frontend_preloads, fn(src) {
          html.link([
            attribute.rel("modulepreload"),
            attribute.href(src),
          ])
        }),
        [
          html.script(
            [
              attribute.type_("module"),
              attribute.src(frontend_src),
            ],
            "",
          ),
        ],
      )
    False -> []
  }

  let html_attributes = case theme {
    option.Some(theme) -> [
      attribute.lang("en"),
      attribute.data("theme", page_theme.to_string(theme)),
    ]
    option.None -> [attribute.lang("en")]
  }

  html.html(html_attributes, [
    html.head([], list.append(base_head, list.append(head_children, tail_head))),
    html.body([], [
      html.div([attribute.id("app"), ..app_attributes], app_children),
    ]),
  ])
  |> element.to_document_string
}
