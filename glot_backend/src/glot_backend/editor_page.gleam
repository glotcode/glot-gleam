import gleam/json
import gleam/option
import glot_web/page/editor
import lustre/attribute
import lustre/element.{type Element}

pub fn title(view_model: editor.ViewModel) -> String {
  editor.title(view_model)
}

pub fn head_children(
  view_model: editor.ViewModel,
  social_image_url: String,
) -> List(Element(Nil)) {
  editor.head_children(view_model, option.Some(social_image_url))
}

pub fn app_attributes(
  view_model: editor.ViewModel,
) -> List(attribute.Attribute(Nil)) {
  [
    attribute.attribute("data-ssr", editor.encode(view_model) |> json.to_string),
  ]
}

pub fn render(view_model: editor.ViewModel) -> Element(Nil) {
  editor.render(view_model)
}
