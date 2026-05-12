import gleam/list
import gleam/option
import glot_frontend/mutation
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type BadgeTone {
  NeutralTone
  InfoTone
  WarningTone
  DangerTone
  SuccessTone
}

pub fn primary_button_class() -> String {
  "admin-page__button"
}

pub fn secondary_button_class() -> String {
  "admin-page__button admin-page__button--secondary"
}

pub fn secondary_link(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  label label: String,
) -> Element(msg) {
  html.a([attribute.class(secondary_button_class()), ..extra_attributes], [
    html.text(label),
  ])
}

pub fn secondary_button(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  label label: String,
) -> Element(msg) {
  html.button([attribute.class(secondary_button_class()), ..extra_attributes], [
    html.text(label),
  ])
}

pub fn page(
  title title: String,
  intro intro: String,
  content content: List(Element(msg)),
) -> Element(msg) {
  page_with_panel_class(
    panel_class: "",
    title: title,
    intro: intro,
    actions: [],
    content: content,
  )
}

pub fn page_with_actions(
  title title: String,
  intro intro: String,
  actions actions: List(Element(msg)),
  content content: List(Element(msg)),
) -> Element(msg) {
  page_with_panel_class(
    panel_class: "",
    title: title,
    intro: intro,
    actions: actions,
    content: content,
  )
}

pub fn page_with_panel_class(
  panel_class panel_class: String,
  title title: String,
  intro intro: String,
  actions actions: List(Element(msg)),
  content content: List(Element(msg)),
) -> Element(msg) {
  let section_class = case panel_class {
    "" -> "app-panel admin-page"
    _ -> "app-panel admin-page " <> panel_class
  }

  let header = case actions {
    [] ->
      html.div([attribute.class("admin-page__header")], [
        html.div([attribute.class("admin-page__heading")], [
          html.h2([attribute.class("admin-page__title")], [html.text(title)]),
          html.p([attribute.class("admin-page__intro")], [html.text(intro)]),
        ]),
      ])
    _ ->
      html.div([attribute.class("admin-page__header")], [
        html.div([attribute.class("admin-page__heading")], [
          html.h2([attribute.class("admin-page__title")], [html.text(title)]),
          html.p([attribute.class("admin-page__intro")], [html.text(intro)]),
        ]),
        html.div([attribute.class("admin-page__actions")], actions),
      ])
  }

  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class(section_class)], [header, ..content]),
    ]),
  ])
}

pub fn badge(text: String, tone: BadgeTone) -> Element(msg) {
  html.span([attribute.class(badge_class(tone))], [html.text(text)])
}

pub fn badge_class(tone: BadgeTone) -> String {
  case tone {
    NeutralTone -> "admin-badge"
    InfoTone -> "admin-badge admin-badge--info"
    WarningTone -> "admin-badge admin-badge--warning"
    DangerTone -> "admin-badge admin-badge--danger"
    SuccessTone -> "admin-badge admin-badge--success"
  }
}

pub fn summary_grid_class() -> String {
  "admin-info-grid admin-info-grid--summary"
}

pub fn detail_grid_class() -> String {
  "admin-info-grid admin-info-grid--detail"
}

pub fn summary_card(title title: String, value value: String) -> Element(msg) {
  summary_card_with_class("admin-page__policy", title, value)
}

pub fn summary_card_with_class(
  class_name: String,
  title: String,
  value: String,
) -> Element(msg) {
  html.article([attribute.class(class_name <> " admin-info-card")], [
    html.span([attribute.class("admin-info-label")], [html.text(title)]),
    html.strong(
      [attribute.class("admin-info-value admin-info-value--summary")],
      [
        html.text(value),
      ],
    ),
  ])
}

pub fn detail_item(label: String, value: String) -> Element(msg) {
  html.div([attribute.class("admin-page__policy admin-info-item")], [
    html.span([attribute.class("admin-info-label")], [html.text(label)]),
    html.span([attribute.class("admin-info-value")], [html.text(value)]),
  ])
}

pub fn detail_link_item(
  label: String,
  value: String,
  extra_attributes: List(attribute.Attribute(msg)),
) -> Element(msg) {
  html.div([attribute.class("admin-page__policy admin-info-item")], [
    html.span([attribute.class("admin-info-label")], [html.text(label)]),
    html.a([attribute.class("admin-info-value"), ..extra_attributes], [
      html.text(value),
    ]),
  ])
}

pub fn status(message: String) -> Element(msg) {
  html.p([attribute.class("admin-page__status")], [html.text(message)])
}

pub fn error_status(message: String) -> Element(msg) {
  html.p([attribute.class("admin-page__status admin-page__status--error")], [
    html.text(message),
  ])
}

pub fn empty_state(message: String) -> Element(msg) {
  html.div([attribute.class("admin-page__empty")], [html.text(message)])
}

pub fn mutation_status(
  state: mutation.MutationState,
  saving_text: String,
  saved_text: String,
) -> Element(msg) {
  case state {
    mutation.Idle -> status("")
    mutation.Saving -> status(saving_text)
    mutation.Saved -> status(saved_text)
    mutation.SaveError(message) -> error_status(message)
  }
}

pub fn section(
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
  html.div([attribute.class("admin-page__field-grid"), ..extra_attributes], fields)
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

pub fn text_input(
  label label: String,
  help help: String,
  value value: String,
  placeholder placeholder: String,
  on_input on_input: fn(String) -> msg,
) -> Element(msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.input([
      attribute.type_("text"),
      attribute.class("admin-page__input"),
      attribute.value(value),
      attribute.placeholder(placeholder),
      event.on_input(on_input),
    ]),
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
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.select(
      [
        attribute.class("admin-page__select admin-page__input"),
        attribute.value(value),
        event.on_input(on_input),
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

fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
