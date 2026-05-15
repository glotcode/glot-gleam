import gleam/json
import glot_core/page/site_chrome
import glot_core/page/snippets
import glot_core/page/top_bar
import glot_core/route
import lustre/attribute
import lustre/element.{type Element}

pub fn title() -> String {
  "glot.io - public snippets"
}

pub fn app_attributes(
  view_model: snippets.ViewModel,
) -> List(attribute.Attribute(Nil)) {
  [
    attribute.attribute(
      "data-ssr",
      snippets.encode(view_model) |> json.to_string,
    ),
  ]
}

pub fn render(view_model: snippets.ViewModel) -> Element(Nil) {
  site_chrome.view(
    top_bar_model: top_bar.empty_model(),
    footer_account_route: route.Account(route.AccountHome),
    content: snippets.view(view_model),
  )
}
