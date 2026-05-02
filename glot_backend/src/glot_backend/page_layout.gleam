import lustre/attribute
import lustre/element
import lustre/element/html

pub fn document(
  title title: String,
  app_attributes app_attributes: List(attribute.Attribute(msg)),
  app_children app_children: List(element.Element(msg)),
) -> String {
  html.html([attribute.lang("en")], [
    html.head([], [
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
      html.script(
        [
          attribute.type_("module"),
          attribute.src("/static/glot_frontend.js"),
        ],
        "",
      ),
    ]),
    html.body([], [
      html.div([attribute.id("app"), ..app_attributes], app_children),
    ]),
  ])
  |> element.to_document_string
}
