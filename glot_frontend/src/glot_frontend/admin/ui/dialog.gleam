import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn dialog_form(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.form([attribute.class("app-dialog__form"), ..extra_attributes], children)
}

pub fn dialog_section(content: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("app-dialog__section")], content)
}

pub fn dialog_intro(
  title title: String,
  copy copy: List(Element(msg)),
) -> Element(msg) {
  dialog_section([
    html.p([attribute.class("app-dialog__label")], [html.text(title)]),
    html.p([attribute.class("app-dialog__copy")], copy),
  ])
}

pub fn dialog_header_with_close(
  title title: String,
  copy copy: String,
  close_attributes close_attributes: List(attribute.Attribute(msg)),
  close_label close_label: String,
) -> Element(msg) {
  html.div([attribute.class("admin-page__dialog-header")], [
    html.div([], [
      html.p([attribute.class("app-dialog__label")], [html.text(title)]),
      html.p([attribute.class("app-dialog__copy")], [html.text(copy)]),
    ]),
    html.button(
      [
        attribute.type_("button"),
        attribute.class("admin-page__dialog-close"),
        ..close_attributes
      ],
      [html.text(close_label)],
    ),
  ])
}

pub fn dialog_actions(actions: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("app-dialog__actions")], actions)
}

pub fn dialog_cancel_button(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  label label: String,
) -> Element(msg) {
  dialog_button_with_class(
    "app-dialog__button app-dialog__button--secondary",
    extra_attributes,
    label,
  )
}

pub fn dialog_primary_button(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  label label: String,
) -> Element(msg) {
  dialog_button_with_class("app-dialog__button", extra_attributes, label)
}

pub fn dialog_danger_button(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  label label: String,
) -> Element(msg) {
  dialog_button_with_class(
    "app-dialog__button app-dialog__button--danger",
    extra_attributes,
    label,
  )
}

fn dialog_button_with_class(
  class_name: String,
  extra_attributes: List(attribute.Attribute(msg)),
  label: String,
) -> Element(msg) {
  html.button([attribute.class(class_name), ..extra_attributes], [
    html.text(label),
  ])
}
