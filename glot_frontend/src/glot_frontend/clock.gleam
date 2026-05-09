import gleam/time/timestamp.{type Timestamp}
import glot_core/helpers/timestamp_helpers
import lustre/effect.{type Effect}

pub fn now() -> Timestamp {
  now_milliseconds()
  |> timestamp_helpers.from_unix_milliseconds
}

pub fn schedule_next_tick(on_tick: fn(Timestamp) -> msg) -> Effect(msg) {
  effect.from(fn(dispatch) {
    wait_until_next_tick(fn(now_ms) {
      now_ms
      |> timestamp_helpers.from_unix_milliseconds
      |> on_tick
      |> dispatch
    })
  })
}

@external(javascript, "./clock_ffi.mjs", "nowMilliseconds")
fn now_milliseconds() -> Int

@external(javascript, "./clock_ffi.mjs", "waitUntilNextTick")
fn wait_until_next_tick(on_tick: fn(Int) -> Nil) -> Nil
