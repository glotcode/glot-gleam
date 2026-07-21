import glot_core/loadable
import glot_frontend/admin/ui/layout
import glot_frontend/ui/mutation
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn status(message: String) -> Element(msg) {
  html.p(
    [
      attribute.class("admin-page__status"),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [html.text(message)],
  )
}

pub fn blank_status() -> Element(msg) {
  status("")
}

pub fn error_status(message: String) -> Element(msg) {
  html.p(
    [
      attribute.class("admin-page__status admin-page__status--error"),
      attribute.attribute("role", "alert"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [html.text(message)],
  )
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

pub fn loadable_status(
  state: loadable.Loadable(a),
  loading_text: String,
) -> Element(msg) {
  loadable.fold(
    state,
    blank_status(),
    status(loading_text),
    fn(_) { blank_status() },
    error_status,
  )
}

pub fn loadable_list_content(
  state: loadable.Loadable(List(a)),
  loading_text: String,
  empty_text: String,
  content content: fn(List(a)) -> Element(msg),
) -> Element(msg) {
  loadable.fold(
    state,
    empty_state(empty_text),
    empty_state(loading_text),
    fn(items) {
      case items {
        [] -> empty_state(empty_text)
        _ -> content(items)
      }
    },
    fn(_) { empty_state(empty_text) },
  )
}

pub fn error_badge(has_error: Bool) -> Element(msg) {
  case has_error {
    True -> layout.badge("Error", layout.DangerTone)
    False -> layout.badge("None", layout.SuccessTone)
  }
}
