import glot_core/page/privacy
import glot_core/page/seo
import glot_core/page/site_chrome
import glot_core/page/top_bar
import glot_core/route
import lustre/element.{type Element}

pub fn title() -> String {
  seo.title(metadata())
}

pub fn metadata() -> seo.Metadata {
  seo.privacy()
}

pub fn view() -> Element(Nil) {
  site_chrome.view(
    top_bar_model: top_bar.empty_model(),
    footer_account_route: route.Account(route.AccountHome),
    content: privacy.view(),
  )
}
