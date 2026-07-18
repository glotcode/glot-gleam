import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn document(
  title title: String,
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

  html.html([attribute.lang("en")], [
    html.head([], list.append(base_head, list.append(head_children, tail_head))),
    html.body([], [
      html.div([attribute.id("app"), ..app_attributes], app_children),
    ]),
  ])
  |> element.to_document_string
}
