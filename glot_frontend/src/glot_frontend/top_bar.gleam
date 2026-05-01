import gleam/dynamic/decode
import gleam/int
import gleam/list
import glot_core/route
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub const quick_actions_dialog_id = "app-quick-actions-dialog"

pub type Action(msg) {
  Action(label: String, description: String, shortcut: List(String), msg: msg)
}

pub type Section(msg) {
  Section(title: String, actions: List(Action(msg)))
}

pub type ViewModel(msg) {
  ViewModel(
    current_user_label: String,
    account_route: route.Route,
    search_query: String,
    selected_index: Int,
    open_msg: msg,
    close_msg: msg,
    search_changed: fn(String) -> msg,
    keydown: fn(String) -> msg,
    submit_msg: msg,
    sections: List(Section(msg)),
  )
}

pub fn map_action(action: Action(a), mapper: fn(a) -> b) -> Action(b) {
  case action {
    Action(label:, description:, shortcut:, msg:) ->
      Action(label:, description:, shortcut:, msg: mapper(msg))
  }
}

pub fn view(model: ViewModel(msg)) -> Element(msg) {
  html.header([attribute.class("app-topbar")], [
    html.div([attribute.class("app-topbar__title-group")], [
      html.button(
        [
          attribute.type_("button"),
          attribute.class(
            "app-topbar__icon-button app-topbar__icon-button--menu",
          ),
          attribute.attribute("aria-label", "Open quick actions"),
          event.on_click(model.open_msg),
        ],
        [html.span([attribute.class("app-topbar__menu-icon")], [])],
      ),
      html.a(
        [
          attribute.class("app-topbar__brand"),
          attribute.href("/"),
        ],
        [
          html.text("glot.io"),
        ],
      ),
    ]),
    html.div([attribute.class("app-topbar__account")], [
      html.a(
        [
          attribute.class("app-topbar__account-label"),
          attribute.attribute("aria-label", "Account"),
          route.href(model.account_route),
        ],
        [
          html.text(model.current_user_label),
        ],
      ),
    ]),
    quick_actions_dialog(model),
  ])
}

fn quick_actions_dialog(model: ViewModel(msg)) -> Element(msg) {
  html.dialog(
    [
      attribute.id(quick_actions_dialog_id),
      attribute.class("app-dialog app-quick-actions"),
      event.on("close", decode.success(model.close_msg)),
    ],
    [
      html.form(
        [
          attribute.class("app-dialog__form app-quick-actions__form"),
          event.on_submit(fn(_) { model.submit_msg }),
        ],
        [
          html.div([attribute.class("app-dialog__section")], [
            html.div([attribute.class("app-quick-actions__header")], [
              html.p([attribute.class("app-dialog__label")], [
                html.text("Quick actions"),
              ]),
              html.p([attribute.class("app-quick-actions__hint")], [
                html.code([], [html.text("cmd+k")]),
                html.text("|"),
                html.code([], [html.text("ctrl+k")]),
              ]),
              html.button(
                [
                  attribute.type_("button"),
                  attribute.class("app-quick-actions__close"),
                  attribute.attribute("aria-label", "Close quick actions"),
                  event.on_click(model.close_msg),
                ],
                [html.text("Close")],
              ),
            ]),
            html.input([
              attribute.type_("text"),
              attribute.name("quick-actions-search"),
              attribute.class("app-quick-actions__search"),
              attribute.placeholder("Search actions and languages"),
              attribute.autofocus(True),
              attribute.value(model.search_query),
              event.on_input(model.search_changed),
              event.advanced("keydown", {
                use key <- decode.field("key", decode.string)

                let prevent_default = case key {
                  "ArrowDown" | "ArrowUp" | "Enter" -> True
                  _ -> False
                }

                decode.success(event.handler(
                  model.keydown(key),
                  prevent_default: prevent_default,
                  stop_propagation: False,
                ))
              }),
            ]),
          ]),
          case has_any_actions(model) {
            True ->
              html.div(
                [attribute.class("app-quick-actions__sections")],
                render_sections(model.sections, model.selected_index, 0),
              )
            False ->
              html.p([attribute.class("app-quick-actions__empty")], [
                html.text("No matching actions."),
              ])
          },
        ],
      ),
    ],
  )
}

fn render_sections(
  sections: List(Section(msg)),
  selected_index: Int,
  offset: Int,
) -> List(Element(msg)) {
  case sections {
    [] -> []
    [section, ..rest] -> {
      let #(element, next_offset) =
        action_section(section, selected_index, offset)
      [element, ..render_sections(rest, selected_index, next_offset)]
    }
  }
}

fn action_section(
  section: Section(msg),
  selected_index: Int,
  offset: Int,
) -> #(Element(msg), Int) {
  case section {
    Section(title:, actions:) -> #(
      html.div([attribute.class("app-dialog__section")], [
        html.p([attribute.class("app-dialog__label")], [html.text(title)]),
        html.div(
          [attribute.class("app-quick-actions__list")],
          render_action_buttons(actions, selected_index, offset),
        ),
      ]),
      offset + list.length(actions),
    )
  }
}

fn render_action_buttons(
  actions: List(Action(msg)),
  selected_index: Int,
  offset: Int,
) -> List(Element(msg)) {
  case actions {
    [] -> []
    [action, ..rest] -> [
      action_button(action, offset, offset == selected_index),
      ..render_action_buttons(rest, selected_index, offset + 1)
    ]
  }
}

fn action_button(
  action: Action(msg),
  index: Int,
  selected: Bool,
) -> Element(msg) {
  case action {
    Action(label:, description:, shortcut:, msg:) -> {
      let class_name = case selected {
        True -> "app-quick-actions__item app-quick-actions__item--selected"
        False -> "app-quick-actions__item"
      }

      html.button(
        [
          attribute.type_("button"),
          attribute.class(class_name),
          attribute.attribute("data-quick-action-index", int.to_string(index)),
          event.on_click(msg),
        ],
        [
          html.div([attribute.class("app-quick-actions__item-header")], [
            html.span([attribute.class("app-quick-actions__item-label")], [
              html.text(label),
            ]),
            case shortcut {
              [_, ..] ->
                html.span(
                  [attribute.class("app-quick-actions__item-shortcut")],
                  render_shortcut(shortcut),
                )
              [] -> html.div([], [])
            },
          ]),
          html.span([attribute.class("app-quick-actions__item-copy")], [
            html.text(description),
          ]),
        ],
      )
    }
  }
}

fn has_any_actions(model: ViewModel(msg)) -> Bool {
  case model.sections {
    [] -> False
    _ -> True
  }
}

fn render_shortcut(shortcut: List(String)) -> List(Element(msg)) {
  case shortcut {
    [] -> []
    [combo] -> [html.code([], [html.text(combo)])]
    [combo, ..rest] -> [
      html.code([], [html.text(combo)]),
      html.text("|"),
      ..render_shortcut(rest)
    ]
  }
}
