import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn text_input(
  label label: String,
  help help: String,
  value value: String,
  placeholder placeholder: String,
  on_input on_input: fn(String) -> msg,
) -> Element(msg) {
  text_input_with_attrs(
    label: label,
    help: help,
    value: value,
    placeholder: placeholder,
    input_type: "text",
    field_class: "",
    input_class: "",
    input_attributes: [],
    on_input: on_input,
  )
}

pub fn text_input_with_attrs(
  label label: String,
  help help: String,
  value value: String,
  placeholder placeholder: String,
  input_type input_type: String,
  field_class field_class: String,
  input_class input_class: String,
  input_attributes input_attributes: List(attribute.Attribute(msg)),
  on_input on_input: fn(String) -> msg,
) -> Element(msg) {
  let label_class = case field_class {
    "" -> "admin-page__field"
    _ -> "admin-page__field " <> field_class
  }
  let merged_input_class = case input_class {
    "" -> "admin-page__input"
    _ -> "admin-page__input " <> input_class
  }

  html.label([attribute.class(label_class)], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.input([
      attribute.type_(input_type),
      attribute.class(merged_input_class),
      attribute.value(value),
      attribute.placeholder(placeholder),
      event.on_input(on_input),
      ..input_attributes
    ]),
    html.span([attribute.class("admin-page__field-help")], [html.text(help)]),
  ])
}

pub fn textarea_input(
  label label: String,
  help help: String,
  value value: String,
  rows rows: Int,
  on_input on_input: fn(String) -> msg,
) -> Element(msg) {
  textarea_input_with_attrs(
    label: label,
    help: help,
    value: value,
    rows: rows,
    field_class: "",
    textarea_class: "",
    textarea_attributes: [],
    on_input: on_input,
  )
}

pub fn textarea_input_with_attrs(
  label label: String,
  help help: String,
  value value: String,
  rows rows: Int,
  field_class field_class: String,
  textarea_class textarea_class: String,
  textarea_attributes textarea_attributes: List(attribute.Attribute(msg)),
  on_input on_input: fn(String) -> msg,
) -> Element(msg) {
  let label_class = case field_class {
    "" -> "admin-page__field"
    _ -> "admin-page__field " <> field_class
  }
  let merged_textarea_class = case textarea_class {
    "" -> "admin-page__input"
    _ -> "admin-page__input " <> textarea_class
  }

  html.label([attribute.class(label_class)], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.textarea(
      [
        attribute.class(merged_textarea_class),
        attribute.rows(rows),
        event.on_input(on_input),
        ..textarea_attributes
      ],
      value,
    ),
    html.span([attribute.class("admin-page__field-help")], [html.text(help)]),
  ])
}

pub fn select_input(
  label label: String,
  value value: String,
  on_input on_input: fn(String) -> msg,
  options options: List(#(String, String)),
  help help: String,
) -> Element(msg) {
  select_input_with_attrs(
    label: label,
    value: value,
    on_input: on_input,
    options: options,
    help: help,
    field_class: "",
    select_class: "",
    select_attributes: [],
  )
}

pub fn select_input_with_attrs(
  label label: String,
  value value: String,
  on_input on_input: fn(String) -> msg,
  options options: List(#(String, String)),
  help help: String,
  field_class field_class: String,
  select_class select_class: String,
  select_attributes select_attributes: List(attribute.Attribute(msg)),
) -> Element(msg) {
  let label_class = case field_class {
    "" -> "admin-page__field"
    _ -> "admin-page__field " <> field_class
  }
  let merged_select_class = case select_class {
    "" -> "admin-page__select admin-page__input"
    _ -> "admin-page__select admin-page__input " <> select_class
  }

  html.label([attribute.class(label_class)], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.select(
      [
        attribute.class(merged_select_class),
        attribute.value(value),
        event.on_input(on_input),
        ..select_attributes
      ],
      list.map(options, fn(option_item) {
        let #(option_value, option_label) = option_item
        html.option(
          [
            attribute.value(option_value),
            attribute.selected(option_value == value),
          ],
          option_label,
        )
      }),
    ),
    html.span([attribute.class("admin-page__field-help")], [html.text(help)]),
  ])
}
