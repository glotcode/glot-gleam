import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn document(
  title title: String,
  head_children head_children: List(element.Element(msg)),
  include_frontend include_frontend: Bool,
  app_attributes app_attributes: List(attribute.Attribute(msg)),
  app_children app_children: List(element.Element(msg)),
) -> String {
  let base_head = [
    html.meta([attribute.charset("utf-8")]),
    html.meta([
      attribute.name("viewport"),
      attribute.content("width=device-width, initial-scale=1"),
    ]),
    html.title([], title),
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/static/styles.css"),
    ]),
  ]
  let tail_head = case include_frontend {
    True -> [
      html.script(
        [
          attribute.type_("module"),
          attribute.src("/static/glot_frontend.js"),
        ],
        "",
      ),
    ]
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
