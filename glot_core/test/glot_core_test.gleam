import gleam/time/timestamp
import gleeunit
import glot_core/snippet/snippet_model

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn new_slug_test() {
  let ts =
    timestamp.from_unix_seconds_and_nanoseconds(1_775_312_436, 567_890_000)

  assert snippet_model.new_slug(ts) == "hhan9vius2"
}

pub fn new_slug_truncates_to_microseconds_test() {
  let a = timestamp.from_unix_seconds_and_nanoseconds(42, 123_456_000)
  let b = timestamp.from_unix_seconds_and_nanoseconds(42, 123_456_999)

  assert snippet_model.new_slug(a) == snippet_model.new_slug(b)
}
