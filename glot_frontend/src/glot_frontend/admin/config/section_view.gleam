import gleam/option
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/ui/mutation
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

import glot_frontend/admin/config/section.{
  type LoadState, LoadError, Loading, is_ready,
}

pub fn card(
  title title: String,
  subtitle subtitle: String,
  state state: mutation.MutationState,
  dirty dirty: Bool,
  idle_badge idle_badge: option.Option(String),
  fields fields: Element(msg),
  footer footer: Element(msg),
) -> Element(msg) {
  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text(title),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(subtitle),
          ]),
        ]),
        html.div([attribute.class("admin-page__policy-header-actions")], [
          badge(state, dirty, idle_badge),
        ]),
      ]),
      fields,
      footer,
    ],
  )
}

pub fn footer(
  load_state load_state: LoadState,
  mutation_state mutation_state: mutation.MutationState,
  dirty dirty: Bool,
  idle_message idle_message: option.Option(String),
  reset_msg reset_msg: msg,
  save_msg save_msg: msg,
) -> Element(msg) {
  let save_disabled =
    !is_ready(load_state) || mutation.is_saving(mutation_state) || !dirty

  html.div([attribute.class("admin-page__policy-footer")], [
    state_message(load_state, mutation_state, idle_message),
    html.div([attribute.class("admin-page__actions")], [
      admin_layout.secondary_button(
        [
          attribute.type_("button"),
          attribute.disabled(mutation.is_saving(mutation_state) || !dirty),
          event.on_click(reset_msg),
        ],
        "Reset",
      ),
      html.button(
        [
          attribute.type_("button"),
          attribute.class("admin-page__button"),
          attribute.disabled(save_disabled),
          event.on_click(save_msg),
        ],
        [html.text(save_button_text(mutation_state))],
      ),
    ]),
  ])
}

pub fn empty_badge(is_empty: Bool) -> option.Option(String) {
  case is_empty {
    True -> option.Some("Not configured")
    False -> option.None
  }
}

pub fn empty_message(is_empty: Bool) -> option.Option(String) {
  case is_empty {
    True -> option.Some("This section is empty until you save initial values.")
    False -> option.None
  }
}

pub fn state_message(
  load_state: LoadState,
  mutation_state: mutation.MutationState,
  idle_message: option.Option(String),
) -> Element(msg) {
  let message = case load_state, mutation_state {
    LoadError(message), _ ->
      option.Some(#(
        "admin-page__policy-status admin-page__policy-status--error",
        message,
      ))
    Loading, _ -> option.Some(#("admin-page__policy-status", "Loading..."))
    _, mutation.SaveError(message) ->
      option.Some(#(
        "admin-page__policy-status admin-page__policy-status--error",
        message,
      ))
    _, mutation.Saving ->
      option.Some(#("admin-page__policy-status", "Saving changes..."))
    _, mutation.Saved ->
      option.Some(#("admin-page__policy-status", "Config saved."))
    _, mutation.Idle ->
      idle_message
      |> option.map(fn(message) { #("admin-page__policy-status", message) })
  }

  case message {
    option.Some(#(class_name, text)) ->
      html.p([attribute.class(class_name)], [html.text(text)])
    option.None -> html.div([], [])
  }
}

fn badge(
  state: mutation.MutationState,
  dirty: Bool,
  idle_text: option.Option(String),
) -> Element(msg) {
  case badge_copy(state, dirty, idle_text) {
    option.Some(text) ->
      html.span([attribute.class(badge_class(state, dirty))], [html.text(text)])
    option.None -> html.div([], [])
  }
}

fn badge_copy(
  state: mutation.MutationState,
  dirty: Bool,
  idle_text: option.Option(String),
) -> option.Option(String) {
  case state {
    mutation.SaveError(_) -> option.Some("Error")
    mutation.Saving -> option.Some("Saving")
    mutation.Saved -> option.Some("Saved")
    mutation.Idle ->
      case dirty {
        True -> option.Some("Unsaved")
        False -> idle_text
      }
  }
}

fn badge_class(state: mutation.MutationState, dirty: Bool) -> String {
  case state {
    mutation.SaveError(_) -> "admin-page__version admin-page__version--error"
    mutation.Saving -> "admin-page__version"
    mutation.Saved -> "admin-page__version admin-page__version--success"
    mutation.Idle ->
      case dirty {
        True -> "admin-page__version admin-page__version--dirty"
        False -> "admin-page__version"
      }
  }
}

fn save_button_text(state: mutation.MutationState) -> String {
  case state {
    mutation.Saving -> "Saving..."
    mutation.Idle | mutation.Saved | mutation.SaveError(_) -> "Save"
  }
}
