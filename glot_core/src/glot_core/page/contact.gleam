import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(contact_form: Element(msg)) -> Element(msg) {
  html.main(
    [
      attribute.id("main-content"),
      attribute.attribute("tabindex", "-1"),
      attribute.class("contact-page"),
    ],
    [
      html.article([attribute.class("contact")], [
        html.header([attribute.class("contact__header")], [
          html.p([attribute.class("contact__eyebrow")], [
            html.text("Get in touch"),
          ]),
          html.h1([], [html.text("Contact")]),
          html.p([attribute.class("contact__summary")], [
            html.text(
              "Send a privacy request, report a security vulnerability, or ask a general question.",
            ),
          ]),
        ]),
        contact_form,
      ]),
    ],
  )
}

pub fn contact_form_placeholder() -> Element(msg) {
  html.div([attribute.class("contact-form contact-form--loading")], [
    html.p([], [html.text("Loading contact form…")]),
  ])
}
