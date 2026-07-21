import glot_web/page/contact
import glot_web/page/seo
import glot_web/page/site_chrome
import glot_web/page/top_bar
import glot_core/route
import lustre/element.{type Element}

pub fn title() -> String {
  seo.title(metadata())
}

pub fn metadata() -> seo.Metadata {
  seo.contact()
}

pub fn view() -> Element(Nil) {
  site_chrome.view(
    top_bar_model: top_bar.empty_model(),
    footer_account_route: route.Account(route.AccountHome),
    content: contact.view(contact.contact_form_placeholder()),
  )
}
