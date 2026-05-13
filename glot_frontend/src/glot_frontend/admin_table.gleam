import gleam/list
import gleam/option
import glot_frontend/admin_ui
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub type Column {
  Column(label: String, kind: ColumnKind)
}

pub type ColumnKind {
  DefaultColumn
  FitColumn
  ActionColumn
}

pub fn column(label: String) -> Column {
  Column(label: label, kind: DefaultColumn)
}

pub fn fit_column(label: String) -> Column {
  Column(label: label, kind: FitColumn)
}

pub fn action_column(label: String) -> Column {
  Column(label: label, kind: ActionColumn)
}

pub fn open_column() -> Column {
  action_column("Open")
}

pub fn table(columns: List(Column), rows: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("admin-table__wrap")], [
    html.table([attribute.class("admin-table")], [
      html.thead([], [html.tr([], columns |> list.map(heading))]),
      html.tbody([], rows),
    ]),
  ])
}

pub fn row(cells: List(Element(msg))) -> Element(msg) {
  row_with([], cells)
}

pub fn row_with(
  extra_attributes: List(attribute.Attribute(msg)),
  cells: List(Element(msg)),
) -> Element(msg) {
  html.tr([attribute.class("admin-table__row"), ..extra_attributes], cells)
}

pub fn cell(column: Column, children: List(Element(msg))) -> Element(msg) {
  cell_with(column, [], children)
}

pub fn cell_with(
  column: Column,
  extra_attributes: List(attribute.Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  html.td([attribute.class(cell_class(column)), ..extra_attributes], [
    cell_label(column.label),
    ..children
  ])
}

pub fn value(text: String) -> Element(msg) {
  html.span([attribute.class("admin-table__value")], [html.text(text)])
}

pub fn primary_value(text: String) -> Element(msg) {
  html.span(
    [attribute.class("admin-table__value admin-table__value--primary")],
    [html.text(text)],
  )
}

pub fn primary_link(
  attributes extra_attributes: List(attribute.Attribute(msg)),
  text text: String,
) -> Element(msg) {
  html.a(
    [
      attribute.class(
        "admin-table__value admin-table__value--primary admin-table__link",
      ),
      ..extra_attributes
    ],
    [html.text(text)],
  )
}

pub fn secondary_value(text: String) -> Element(msg) {
  html.span(
    [attribute.class("admin-table__value admin-table__value--secondary")],
    [html.text(text)],
  )
}

pub fn meta(text: String) -> Element(msg) {
  html.span([attribute.class("admin-table__meta")], [html.text(text)])
}

pub fn stack(children: List(Element(msg))) -> Element(msg) {
  html.div([attribute.class("admin-table__stack")], children)
}

pub fn value_cell(column: Column, text: String) -> Element(msg) {
  cell(column, [value(text)])
}

pub fn primary_cell(column: Column, text: String) -> Element(msg) {
  cell(column, [primary_value(text)])
}

pub fn secondary_cell(column: Column, text: String) -> Element(msg) {
  cell(column, [secondary_value(text)])
}

pub fn primary_secondary_cell(
  column: Column,
  primary primary: String,
  secondary secondary: option.Option(String),
) -> Element(msg) {
  let children = case secondary {
    option.Some(secondary) -> [
      primary_value(primary),
      secondary_value(secondary),
    ]
    option.None -> [primary_value(primary)]
  }

  cell(column, [stack(children)])
}

pub fn primary_meta_cell(
  column: Column,
  primary primary: String,
  meta_text meta_text: option.Option(String),
) -> Element(msg) {
  let children = case meta_text {
    option.Some(meta_text) -> [primary_value(primary), meta(meta_text)]
    option.None -> [primary_value(primary)]
  }

  cell(column, [stack(children)])
}

pub fn linked_primary_cell(
  column: Column,
  attributes extra_attributes: List(attribute.Attribute(msg)),
  primary primary: String,
  secondary secondary: option.Option(String),
) -> Element(msg) {
  let children = case secondary {
    option.Some(secondary) -> [
      primary_link(extra_attributes, primary),
      secondary_value(secondary),
    ]
    option.None -> [primary_link(extra_attributes, primary)]
  }

  cell(column, [stack(children)])
}

pub fn action_link_cell(
  column: Column,
  attributes extra_attributes: List(attribute.Attribute(msg)),
  label label: String,
) -> Element(msg) {
  cell(column, [admin_ui.secondary_link(extra_attributes, label)])
}

pub fn open_link_cell(
  attributes extra_attributes: List(attribute.Attribute(msg)),
) -> Element(msg) {
  action_link_cell(open_column(), extra_attributes, "Open")
}

fn heading(column: Column) -> Element(msg) {
  html.th([attribute.class(heading_class(column))], [html.text(column.label)])
}

fn heading_class(column: Column) -> String {
  case column.kind {
    DefaultColumn -> "admin-table__heading"
    FitColumn -> "admin-table__heading admin-table__heading--fit"
    ActionColumn -> "admin-table__heading admin-table__heading--fit"
  }
}

fn cell_class(column: Column) -> String {
  case column.kind {
    DefaultColumn -> "admin-table__cell"
    FitColumn -> "admin-table__cell admin-table__cell--fit"
    ActionColumn -> "admin-table__cell admin-table__cell--actions"
  }
}

fn cell_label(text: String) -> Element(msg) {
  html.span([attribute.class("admin-table__label")], [html.text(text)])
}
