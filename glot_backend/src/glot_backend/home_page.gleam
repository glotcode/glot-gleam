import glot_web/page/home
import glot_web/page/seo
import glot_web/page/site_chrome
import glot_web/page/top_bar
import glot_core/route
import lustre/element.{type Element}

pub fn title() -> String {
  seo.title(metadata())
}

pub fn metadata() -> seo.Metadata {
  seo.home()
}

pub fn view() -> Element(Nil) {
  site_chrome.view(
    top_bar_model: top_bar.empty_model(),
    footer_account_route: route.Account(route.AccountHome),
    content: home.view(load_ad: False),
  )
}
