import gleam/json
import gleam/option
import glot_web/page/seo
import glot_web/page/site_chrome
import glot_web/page/snippets
import glot_web/page/top_bar
import glot_core/route
import lustre/attribute
import lustre/element.{type Element}

pub fn metadata(
  username: option.Option(String),
  canonical_path: String,
) -> seo.Metadata {
  seo.snippets(username, canonical_path)
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
    content: snippets.view(view_model, True),
  )
}
