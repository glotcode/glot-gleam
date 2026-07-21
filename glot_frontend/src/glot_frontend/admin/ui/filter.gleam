import gleam/option
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn filter_section(
  copy copy: String,
  content content: Element(msg),
) -> Element(msg) {
  section(title: "Filters", copy: copy, content: content)
}

pub fn filter_surface(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  content content: List(Element(msg)),
) -> Element(msg) {
  html.div(
    [attribute.class("admin-page__policy admin-filters"), ..extra_attributes],
    content,
  )
}

pub fn filter_field_grid(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  fields fields: List(Element(msg)),
) -> Element(msg) {
  html.div(
    [attribute.class("admin-page__field-grid"), ..extra_attributes],
    fields,
  )
}

pub fn filter_row(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  content content: List(Element(msg)),
) -> Element(msg) {
  html.div([attribute.class("admin-filters__row"), ..extra_attributes], content)
}

pub fn filter_group(
  title title: String,
  copy copy: option.Option(String),
  content content: Element(msg),
) -> Element(msg) {
  let children = case copy {
    option.Some(text) -> [
      html.span([attribute.class("admin-filters__title")], [html.text(title)]),
      html.p([attribute.class("admin-filters__copy")], [html.text(text)]),
      content,
    ]
    option.None -> [
      html.span([attribute.class("admin-filters__title")], [html.text(title)]),
      content,
    ]
  }

  html.div([attribute.class("admin-filters__group")], children)
}

pub fn filter_chip_group(
  title title: String,
  copy copy: option.Option(String),
  chips chips: List(Element(msg)),
) -> Element(msg) {
  filter_group(
    title: title,
    copy: copy,
    content: html.div([attribute.class("admin-page__actions")], chips),
  )
}

pub fn filter_actions(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  actions actions: List(Element(msg)),
) -> Element(msg) {
  html.div(
    [attribute.class("admin-filters__actions"), ..extra_attributes],
    actions,
  )
}

pub fn filter_chip(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  label label: String,
  selected selected: Bool,
) -> Element(msg) {
  let class_name = case selected {
    True -> "admin-page__chip admin-page__chip--selected"
    False -> "admin-page__chip"
  }

  html.button(
    [
      attribute.class(class_name),
      attribute.type_("button"),
      attribute.attribute("aria-pressed", bool_attribute(selected)),
      ..extra_attributes
    ],
    [html.text(label)],
  )
}

fn section(
  title title: String,
  copy copy: String,
  content content: Element(msg),
) -> Element(msg) {
  html.div([attribute.class("admin-page__group")], [
    html.div([attribute.class("admin-page__group-header")], [
      html.h3([attribute.class("admin-page__group-title")], [html.text(title)]),
      html.p([attribute.class("admin-page__group-copy")], [html.text(copy)]),
    ]),
    content,
  ])
}

fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
