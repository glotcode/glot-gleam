import gleam/float
import gleam/int
import gleam/string

pub fn duration_in_ms_label(duration_ns: Int) -> String {
  let hundredths_of_ms =
    int.to_float(duration_ns) /. 10_000.0
    |> float.round

  let whole_ms = hundredths_of_ms / 100
  let fractional_ms =
    hundredths_of_ms % 100
    |> int.to_string
    |> string.pad_start(to: 2, with: "0")

  int.to_string(whole_ms) <> "." <> fractional_ms <> "ms"
}
