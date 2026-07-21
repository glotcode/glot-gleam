import gleam/option
import glot_core/loadable
import glot_core/pagination_model
import glot_frontend/admin/ui/status
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn actions(
  page page: pagination_model.CursorPage(a),
  previous_msg previous_msg: msg,
  next_msg next_msg: msg,
  disabled disabled: Bool,
) -> List(Element(msg)) {
  [
    button("Previous", disabled || !has_previous_page(page), previous_msg),
    button("Next", disabled || !has_next_page(page), next_msg),
  ]
}

pub fn controls(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  page page: pagination_model.CursorPage(a),
  previous_msg previous_msg: msg,
  next_msg next_msg: msg,
  disabled disabled: Bool,
) -> Element(msg) {
  html.div(
    extra_attributes,
    actions(page:, previous_msg:, next_msg:, disabled:),
  )
}

pub fn empty_cursor_page() -> pagination_model.CursorPage(a) {
  pagination_model.InitialCursorPage(items: [], next_cursor: option.None)
}

pub fn current_cursor_page(
  state: loadable.Loadable(pagination_model.CursorPage(a)),
) -> pagination_model.CursorPage(a) {
  case state {
    loadable.Loaded(page) -> page
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) ->
      empty_cursor_page()
  }
}

pub fn loadable_cursor_page_content(
  state: loadable.Loadable(pagination_model.CursorPage(a)),
  loading_text: String,
  empty_text: String,
  content content: fn(List(a)) -> Element(msg),
) -> Element(msg) {
  loadable.fold(
    state,
    status.empty_state(empty_text),
    status.empty_state(loading_text),
    fn(page) {
      case pagination_model.items(page) {
        [] -> status.empty_state(empty_text)
        items -> content(items)
      }
    },
    fn(_) { status.empty_state(empty_text) },
  )
}

pub fn cursor_pagination_actions(
  page page: pagination_model.CursorPage(a),
  previous_msg previous_msg: msg,
  next_msg next_msg: msg,
) -> List(Element(msg)) {
  actions(page:, previous_msg:, next_msg:, disabled: False)
}

pub fn cursor_pagination_actions_with_disabled(
  page page: pagination_model.CursorPage(a),
  previous_msg previous_msg: msg,
  next_msg next_msg: msg,
  disabled disabled: Bool,
) -> List(Element(msg)) {
  actions(page:, previous_msg:, next_msg:, disabled:)
}

pub fn cursor_pagination_controls(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  page page: pagination_model.CursorPage(a),
  previous_msg previous_msg: msg,
  next_msg next_msg: msg,
) -> Element(msg) {
  controls(
    attributes: extra_attributes,
    page:,
    previous_msg:,
    next_msg:,
    disabled: False,
  )
}

pub fn cursor_pagination_controls_with_disabled(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  page page: pagination_model.CursorPage(a),
  previous_msg previous_msg: msg,
  next_msg next_msg: msg,
  disabled disabled: Bool,
) -> Element(msg) {
  controls(
    attributes: extra_attributes,
    page:,
    previous_msg:,
    next_msg:,
    disabled:,
  )
}

fn button(label: String, disabled: Bool, message: msg) -> Element(msg) {
  html.button(
    [
      attribute.class("admin-page__button admin-page__button--secondary"),
      attribute.type_("button"),
      attribute.disabled(disabled),
      event.on_click(message),
    ],
    [html.text(label)],
  )
}

fn has_previous_page(page: pagination_model.CursorPage(a)) -> Bool {
  option.is_some(pagination_model.previous_cursor(page))
}

fn has_next_page(page: pagination_model.CursorPage(a)) -> Bool {
  option.is_some(pagination_model.next_cursor(page))
}
