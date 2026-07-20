import gleam/json
import gleam/option
import gleam/string
import glot_backend/system/cache/cache_outcome
import glot_backend/system/effect/basic/basic_algebra
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/transaction/transaction_algebra
import glot_backend/system/http/server_timing

pub fn external_effect_category_is_short_test() {
  assert effect_trace.effect_category_to_string(effect_trace.ExternalCategory)
    == "external"
}

pub fn rolled_back_transaction_effect_is_marked_test() {
  let rolled_back_measurement =
    effect_trace.EffectMeasurement(
      name: effect_trace.TransactionEffectName(
        transaction_algebra.RunEffectName,
        [
          effect_trace.EffectMeasurement(
            name: effect_trace.BasicEffectName(basic_algebra.NewTokenEffectName),
            category: effect_trace.RuntimeCategory,
            source: option.None,
            duration_ns: 5,
          ),
        ],
        rolled_back: True,
      ),
      category: effect_trace.WriteCategory,
      source: option.Some(effect_trace.DatabaseEffectSource),
      duration_ns: 10,
    )

  let encoded =
    rolled_back_measurement
    |> effect_trace.encode_effect_measurement
    |> json.to_string

  assert string.contains(encoded, "\"rolled_back\":true")

  let timing = server_timing.prepare([rolled_back_measurement], 10)
  assert string.contains(timing, "Transaction;desc=\"Begin\"")
  assert string.contains(timing, "Transaction;desc=\"Rollback\";dur=")
}

pub fn cache_read_effect_provenance_is_serialized_test() {
  let measurement =
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.NewTokenEffectName),
      category: effect_trace.ReadCategory,
      source: option.Some(effect_trace.CacheEffectSource(
        cache_outcome.StaleCacheHit,
      )),
      duration_ns: 5,
    )
    |> effect_trace.encode_effect_measurement
    |> json.to_string

  assert string.contains(measurement, "\"category\":\"read\"")
  assert string.contains(measurement, "\"source\":\"cache\"")
  assert string.contains(measurement, "\"cache_outcome\":\"stale_hit\"")
}
