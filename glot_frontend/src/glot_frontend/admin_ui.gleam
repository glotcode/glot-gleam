import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

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
