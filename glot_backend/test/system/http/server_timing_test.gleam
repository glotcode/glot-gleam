import gleam/option
import gleam/string
import glot_backend/system/effect/basic/basic_algebra
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/transaction/transaction_algebra
import glot_backend/system/http/server_timing

pub fn server_timing_labels_non_effectful_time_test() {
  assert string.starts_with(
    server_timing.prepare([], 1_000_000),
    "Pure;desc=\"Non-effectful\";dur=",
  )
}

pub fn server_timing_formats_uuid_v7_test() {
  let measurement =
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.UuidV7EffectName),
      category: effect_trace.RuntimeCategory,
      source: option.None,
      duration_ns: 1_000_000,
    )

  assert string.contains(
    server_timing.prepare([measurement], 1_000_000),
    "Runtime;desc=\"UUIDv7\";dur=",
  )
}

pub fn empty_transaction_server_timing_has_no_empty_entry_test() {
  let measurement =
    effect_trace.EffectMeasurement(
      name: effect_trace.TransactionEffectName(
        transaction_algebra.RunEffectName,
        [],
        rolled_back: False,
      ),
      category: effect_trace.WriteCategory,
      source: option.Some(effect_trace.DatabaseEffectSource),
      duration_ns: 10,
    )

  let timing = server_timing.prepare([measurement], 10)

  assert !string.contains(timing, ",,")
  assert string.contains(timing, "Transaction;desc=\"Begin\"")
  assert string.contains(timing, "Transaction;desc=\"Commit\";dur=")
}
