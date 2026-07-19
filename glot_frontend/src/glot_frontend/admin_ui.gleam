import gleam/list
import gleam/option
import glot_core/pagination_model
import glot_frontend/json_helpers
import glot_core/loadable
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
          html.h1([attribute.class("admin-page__title")], [html.text(title)]),
          html.p([attribute.class("admin-page__intro")], [html.text(intro)]),
        ]),
      ])
    _ ->
      html.div([attribute.class("admin-page__header")], [
        html.div([attribute.class("admin-page__heading")], [
          html.h1([attribute.class("admin-page__title")], [html.text(title)]),
          html.p([attribute.class("admin-page__intro")], [html.text(intro)]),
        ]),
        html.div([attribute.class("admin-page__actions")], actions),
      ])
  }

  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main(
      [
        attribute.id("main-content"),
        attribute.attribute("tabindex", "-1"),
        attribute.class("app-shell"),
      ],
      [
        html.section([attribute.class(section_class)], [header, ..content]),
      ],
    ),
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

pub fn code_block(value: String) -> Element(msg) {
  html.div([attribute.class("admin-page__policy")], [
    html.pre([attribute.class("admin-page__code-block")], [html.text(value)]),
  ])
}

pub fn named_code_block(
  title title: String,
  value value: String,
) -> Element(msg) {
  html.div([attribute.class("admin-page__group")], [
    html.h4([attribute.class("admin-page__group-title")], [html.text(title)]),
    code_block(value),
  ])
}

pub fn optional_code_block(value: option.Option(String)) -> Element(msg) {
  case value {
    option.Some(text) -> code_block(text)
    option.None -> code_block("None")
  }
}

pub fn optional_raw_block(
  title title: String,
  value value: option.Option(String),
) -> Element(msg) {
  named_code_block(
    title: title,
    value: json_helpers.optional_pretty_print_json_or_none(value),
  )
}

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
    empty_state(empty_text),
    empty_state(loading_text),
    fn(page) {
      case pagination_model.items(page) {
        [] -> empty_state(empty_text)
        items -> content(items)
      }
    },
    fn(_) { empty_state(empty_text) },
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

pub fn form_status_block(content: Element(msg)) -> Element(msg) {
  html.div([attribute.class("admin-page__form-status")], [content])
}

pub fn form_actions(actions: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("admin-page__actions")], actions)
}

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

pub fn cursor_pagination_actions(
  page page: pagination_model.CursorPage(a),
  previous_msg previous_msg: msg,
  next_msg next_msg: msg,
) -> List(Element(msg)) {
  cursor_pagination_actions_with_disabled(
    page: page,
    previous_msg: previous_msg,
    next_msg: next_msg,
    disabled: False,
  )
}

pub fn cursor_pagination_actions_with_disabled(
  page page: pagination_model.CursorPage(a),
  previous_msg previous_msg: msg,
  next_msg next_msg: msg,
  disabled disabled: Bool,
) -> List(Element(msg)) {
  [
    secondary_button(
      [
        attribute.type_("button"),
        attribute.disabled(disabled || !has_previous_page(page)),
        event.on_click(previous_msg),
      ],
      "Previous",
    ),
    secondary_button(
      [
        attribute.type_("button"),
        attribute.disabled(disabled || !has_next_page(page)),
        event.on_click(next_msg),
      ],
      "Next",
    ),
  ]
}

pub fn cursor_pagination_controls(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  page page: pagination_model.CursorPage(a),
  previous_msg previous_msg: msg,
  next_msg next_msg: msg,
) -> Element(msg) {
  cursor_pagination_controls_with_disabled(
    attributes: extra_attributes,
    page: page,
    previous_msg: previous_msg,
    next_msg: next_msg,
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
  html.div(
    extra_attributes,
    cursor_pagination_actions_with_disabled(
      page: page,
      previous_msg: previous_msg,
      next_msg: next_msg,
      disabled: disabled,
    ),
  )
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

pub fn error_badge(has_error: Bool) -> Element(msg) {
  case has_error {
    True -> badge("Error", DangerTone)
    False -> badge("None", SuccessTone)
  }
}

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

fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn has_previous_page(page: pagination_model.CursorPage(a)) -> Bool {
  case pagination_model.previous_cursor(page) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn has_next_page(page: pagination_model.CursorPage(a)) -> Bool {
  case pagination_model.next_cursor(page) {
    option.Some(_) -> True
    option.None -> False
  }
}
