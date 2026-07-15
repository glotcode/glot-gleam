import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

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
        html.script(
          [
            attribute.attribute("async", ""),
            attribute.type_("text/javascript"),
            attribute.src(
              "//cdn.carbonads.com/carbon.js?serve=CKYIE2JM&placement=glotio&format=cover",
            ),
            attribute.id("_carbonads_js"),
          ],
          "",
        ),
      ]
      False -> []
    },
  )
}
