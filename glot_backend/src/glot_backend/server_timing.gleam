import gleam/float
import gleam/int
import gleam/list
import gleam/string
import glot_backend/effect/effect_trace

pub fn prepare(
  ems: List(effect_trace.EffectMeasurement),
  total_duration_ns: Int,
) -> String {
  let effects_duration_ns =
    list.fold(ems, 0, fn(acc, em) { acc + em.duration_ns })
  let domain_duration_ns = int.max(total_duration_ns - effects_duration_ns, 0)

  "Pure;desc=\"Non-effectful\";dur="
  <> float.to_string(int.to_float(domain_duration_ns) /. 1_000_000.0)
  <> ","
  <> prepare_effect_timings(ems)
}

fn prepare_effect_timings(ems: List(effect_trace.EffectMeasurement)) -> String {
  ems
  |> list.map(prepare_effect_timing)
  |> string.join(",")
}

fn prepare_effect_timing(em: effect_trace.EffectMeasurement) -> String {
  case em.name {
    effect_trace.TransactionEffectName(_, ems, rolled_back:) -> {
      let sub_duration = list.fold(ems, 0, fn(acc, e) { acc + e.duration_ns })
      let tx_duration = em.duration_ns - sub_duration
      let tx_end_description = case rolled_back {
        True -> "Rollback"
        False -> "Commit"
      }

      let begin_timing = "Transaction;desc=\"Begin\""
      let end_timing =
        "Transaction;desc=\""
        <> tx_end_description
        <> "\";dur="
        <> float.to_string(int.to_float(tx_duration) /. 1_000_000.0)

      [
        begin_timing,
        ..list.append(list.map(ems, prepare_effect_timing), [end_timing])
      ]
      |> string.join(",")
    }

    _ -> {
      let duration_ms =
        float.to_string(int.to_float(em.duration_ns) /. 1_000_000.0)
      let name =
        snake_to_pascal_case(effect_trace.effect_category_to_string(em.category))
      let desc =
        snake_to_pascal_case(effect_trace.effect_name_to_string(em.name))

      name <> ";desc=\"" <> desc <> "\";dur=" <> duration_ms
    }
  }
}

fn snake_to_pascal_case(value: String) -> String {
  case value {
    "uuid_v7" -> "UUIDv7"
    _ ->
      value
      |> string.split("_")
      |> list.map(fn(segment) {
        case string.slice(segment, at_index: 0, length: 1) {
          "" -> ""
          first ->
            string.uppercase(first)
            <> string.slice(
              segment,
              at_index: 1,
              length: string.length(segment),
            )
        }
      })
      |> string.join("")
  }
}
