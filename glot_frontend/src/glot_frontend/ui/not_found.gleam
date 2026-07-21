import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view() -> Element(msg) {
  html.main(
    [
      attribute.id("main-content"),
      attribute.attribute("tabindex", "-1"),
    ],
    [html.h1([], [html.text("404 Not Found")])],
  )
}
