import glot_core/page/footer
import glot_core/page/top_bar
import glot_core/route
import lustre/element.{type Element}
import lustre/element/html

pub fn view(
  top_bar_model top_bar_model: top_bar.ViewModel(msg),
  footer_account_route footer_account_route: route.Route,
  content content: Element(msg),
) -> Element(msg) {
  html.div([], [
    top_bar.view(top_bar_model),
    content,
    footer.view(account_route: footer_account_route),
  ])
}
