import gleam/int
import gleam/list
import gleam/option
import glot_core/effect_trace_dto
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/duration_label
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

type EffectTableRow {
  EffectTableRow(
    name: String,
    category: String,
    duration_ns: option.Option(Int),
    is_rollback: Bool,
  )
}

pub fn effects_block(
  value: option.Option(effect_trace_dto.EffectTraceResponse),
) -> Element(msg) {
  html.div([attribute.class("admin-page__group")], [
    html.h4([attribute.class("admin-page__group-title")], [html.text("Effects")]),
    case value {
      option.None -> admin_ui.code_block("None")
      option.Some(effect_trace) -> effects_table(effect_trace)
    },
  ])
}

fn effects_table(
  effect_trace: effect_trace_dto.EffectTraceResponse,
) -> Element(msg) {
  let effect_trace_dto.EffectTraceResponse(effects:) = effect_trace
  let rows = build_effect_rows(effects)

  case rows {
    [] ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No effects were recorded for this run."),
      ])
    _ -> admin_table.table(effect_columns(), { rows |> list.map(effect_row) })
  }
}

fn effect_row(row: EffectTableRow) -> Element(msg) {
  let EffectTableRow(name:, category:, duration_ns:, is_rollback:) = row
  let extra_attributes = case is_rollback {
    True -> [attribute.class("admin-table__row--rollback")]
    False -> []
  }

  admin_table.row_with(extra_attributes, [
    admin_table.cell(name_column(), [admin_table.primary_value(name)]),
    admin_table.cell(category_column(), [admin_table.value(category)]),
    admin_table.cell(duration_column(), [
      html.text(optional_duration_label(duration_ns)),
    ]),
  ])
}

fn effect_columns() -> List(admin_table.Column) {
  [name_column(), category_column(), duration_column()]
}

fn name_column() -> admin_table.Column {
  admin_table.column("Name")
}

fn category_column() -> admin_table.Column {
  admin_table.column("Category")
}

fn duration_column() -> admin_table.Column {
  admin_table.fit_column("Duration")
}

fn optional_duration_label(duration_ns: option.Option(Int)) -> String {
  case duration_ns {
    option.Some(duration_ns) -> duration_label.duration_in_ms_label(duration_ns)
    option.None -> "-"
  }
}

fn build_effect_rows(
  effects: List(effect_trace_dto.EffectMeasurementResponse),
) -> List(EffectTableRow) {
  list.fold(effects, [], fn(acc, effect_measurement) {
    list.append(acc, effect_rows_for_measurement(effect_measurement))
  })
}

fn effect_rows_for_measurement(
  effect_measurement: effect_trace_dto.EffectMeasurementResponse,
) -> List(EffectTableRow) {
  case effect_measurement.rolled_back {
    option.Some(rolled_back) -> {
      let sub_effect_duration_ns =
        list.fold(effect_measurement.effects, 0, fn(acc, effect_measurement) {
          acc + effect_measurement.duration_ns
        })
      let tx_duration_ns =
        int.max(effect_measurement.duration_ns - sub_effect_duration_ns, 0)
      let end_name = case rolled_back {
        True -> "tx_rollback"
        False -> "tx_commit"
      }
      let begin_row =
        EffectTableRow(
          name: "tx_begin",
          category: effect_measurement.category,
          duration_ns: option.None,
          is_rollback: False,
        )
      let child_rows = build_effect_rows(effect_measurement.effects)
      let end_row =
        EffectTableRow(
          name: end_name,
          category: effect_measurement.category,
          duration_ns: option.Some(tx_duration_ns),
          is_rollback: rolled_back,
        )

      list.append([begin_row], child_rows)
      |> list.append([end_row])
    }
    option.None -> [
      EffectTableRow(
        name: effect_measurement.name,
        category: effect_measurement.category,
        duration_ns: option.Some(effect_measurement.duration_ns),
        is_rollback: False,
      ),
    ]
  }
}
