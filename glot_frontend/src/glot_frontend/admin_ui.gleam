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
