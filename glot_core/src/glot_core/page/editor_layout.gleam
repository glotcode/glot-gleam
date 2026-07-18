import gleam/list
import glot_core/page/carbon_ad
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn shell_button(
  class_name class_name: String,
  attributes attributes: List(attribute.Attribute(msg)),
  children children: List(Element(msg)),
) -> Element(msg) {
  html.button(
    [attribute.type_("button"), attribute.class(class_name), ..attributes],
    children,
  )
}

pub fn title_hint_button(
  class_name class_name: String,
  aria_label aria_label: String,
  hint_class hint_class: String,
  hint_label hint_label: String,
  attributes attributes: List(attribute.Attribute(msg)),
) -> Element(msg) {
  shell_button(
    class_name: class_name,
    attributes: [attribute.attribute("aria-label", aria_label), ..attributes],
    children: [
      html.span([attribute.class(hint_class)], [html.text(hint_label)]),
    ],
  )
}

pub fn shell(
  load_ad load_ad: Bool,
  title title: String,
  title_actions title_actions: List(Element(msg)),
  pre_tabbar_children pre_tabbar_children: List(Element(msg)),
  tabbar_children tabbar_children: List(Element(msg)),
  editor editor: Element(msg),
  action_buttons action_buttons: List(Element(msg)),
  console console: Element(msg),
) -> Element(msg) {
  let shell_children =
    [bezel(title:, title_actions:)]
    |> list.append(pre_tabbar_children)
    |> list.append([
      tabbar(tabbar_children),
      editor_surface(editor),
      action_bar(action_buttons),
      console,
    ])

  html.div([attribute.class("editor-page")], [
    html.div([attribute.class("editor-page__screen-glow")], []),
    html.main(
      [
        attribute.id("main-content"),
        attribute.attribute("tabindex", "-1"),
        attribute.class("editor-shell"),
      ],
      [
        html.div([attribute.class("editor-shell__workspace")], shell_children),
        html.section([attribute.class("editor-sponsor")], [
          carbon_ad.view(container_class: "editor-sponsor__ad", load_ad:),
        ]),
      ],
    ),
  ])
}

pub fn bezel(
  title title: String,
  title_actions title_actions: List(Element(msg)),
) -> Element(msg) {
  html.div([attribute.class("editor-shell__bezel")], [
    title_row(title:, title_actions:),
  ])
}

pub fn title_row(
  title title: String,
  title_actions title_actions: List(Element(msg)),
) -> Element(msg) {
  html.div([attribute.class("editor-page__title-row")], [
    html.h1([attribute.class("editor-page__title")], [html.text(title)]),
    html.div([attribute.class("editor-page__title-actions")], title_actions),
  ])
}

pub fn tabbar(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("editor-shell__tabbar")], children)
}

pub fn tab_scroll(tabs: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("editor-shell__tab-scroll")], [
    html.div([attribute.class("editor-shell__tab-strip")], tabs),
  ])
}

pub fn tab_button(
  label label: String,
  is_selected is_selected: Bool,
  attributes attributes: List(attribute.Attribute(msg)),
) -> Element(msg) {
  let class_name = case is_selected {
    True -> "editor-shell__tab editor-shell__tab--selected"
    False -> "editor-shell__tab"
  }

  shell_button(
    class_name: class_name,
    attributes: [
      attribute.attribute("aria-pressed", bool_attribute(is_selected)),
      ..attributes
    ],
    children: [html.span([], [html.text(label)])],
  )
}

pub fn tab_meta_button(
  aria_label aria_label: String,
  pill_label pill_label: String,
  attributes attributes: List(attribute.Attribute(msg)),
) -> Element(msg) {
  shell_button(
    class_name: "editor-shell__tab-meta-button",
    attributes: [attribute.attribute("aria-label", aria_label), ..attributes],
    children: [
      html.span([attribute.class("editor-shell__tab-meta-pill")], [
        html.text(pill_label),
      ]),
    ],
  )
}

pub fn editor_surface(content: Element(msg)) -> Element(msg) {
  html.div([attribute.class("editor-shell__editor")], [content])
}

pub fn action_bar(buttons: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("editor-shell__actions")], buttons)
}

pub fn console_shell(
  header header: Element(msg),
  body body: Element(msg),
) -> Element(msg) {
  html.div([attribute.class("editor-shell__console")], [
    header,
    html.div([attribute.class("editor-shell__console-body")], [body]),
  ])
}

pub fn dialog_form(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("editor-page__dialog-form")], children)
}

pub fn dialog_panel(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("editor-page__dialog-panel")], children)
}

pub fn dialog_actions(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("editor-page__dialog-actions")], children)
}

pub fn dialog_info_heading() -> Element(msg) {
  html.h2(
    [
      attribute.class(
        "editor-page__dialog-label editor-page__dialog-label--snippet-info",
      ),
    ],
    [html.text("Snippet info")],
  )
}

pub fn dialog_info_row(label: String, value: String) -> Element(msg) {
  dialog_panel([
    html.span([attribute.class("editor-page__dialog-sublabel")], [
      html.text(label),
    ]),
    html.p([attribute.class("editor-page__dialog-copy")], [
      html.text(value),
    ]),
  ])
}

fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
