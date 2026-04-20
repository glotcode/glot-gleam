import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(current_user_label: String) -> Element(msg) {
  html.header([attribute.class("app-topbar")], [
    html.div([attribute.class("app-topbar__title-group")], [
      html.button(
        [
          attribute.type_("button"),
          attribute.class("app-topbar__icon-button app-topbar__icon-button--menu"),
        ],
        [html.span([attribute.class("app-topbar__menu-icon")], [])],
      ),
      html.a([
        attribute.class("app-topbar__brand"),
        attribute.href("/"),
      ], [
        html.text("glot.io"),
      ]),
    ]),
    html.div([attribute.class("app-topbar__account")], [
      html.span([
        attribute.class("app-topbar__account-label"),
        attribute.attribute("aria-label", "Account"),
      ], [
        html.text(current_user_label),
      ]),
    ]),
  ])
}
