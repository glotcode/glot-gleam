import gleam/list
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
