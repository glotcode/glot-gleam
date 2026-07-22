import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub const path = "/ads/carbon"

const script_src = "https://cdn.carbonads.com/carbon.js?serve=CKYIE2JM&placement=glotio&format=cover"

pub fn view(
  container_class container_class: String,
  load_ad load_ad: Bool,
) -> Element(msg) {
  html.div(
    [
      attribute.id("carbon-ad-container"),
      attribute.class(container_class),
    ],
    case load_ad {
      True -> [
        html.iframe([
          attribute.class("carbon-ad-frame"),
          attribute.src(path),
          attribute.title("Sponsored advertisement"),
          attribute.referrerpolicy("strict-origin-when-cross-origin"),
          attribute.attribute(
            "sandbox",
            "allow-scripts allow-popups allow-popups-to-escape-sandbox",
          ),
        ]),
      ]
      False -> []
    },
  )
}

pub fn document() -> String {
  html.html([attribute.lang("en")], [
    html.head([], [
      html.meta([attribute.charset("utf-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1"),
      ]),
      html.title([], "Sponsored advertisement"),
      html.style(
        [],
        "html,body{margin:0;min-height:100%;overflow:hidden}body{display:grid;place-items:start center}#carbon-cover{width:100%;margin:0 auto}",
      ),
    ]),
    html.body([], [
      html.script(
        [
          attribute.attribute("async", ""),
          attribute.type_("text/javascript"),
          attribute.src(script_src),
          attribute.id("_carbonads_js"),
        ],
        "",
      ),
    ]),
  ])
  |> element.to_document_string
}
