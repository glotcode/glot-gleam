import gleam/time/timestamp
import gleeunit
import glot_core/auth/user_model
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

pub fn is_valid_username_accepts_valid_values_test() {
  assert user_model.is_valid_username("abc")
  assert user_model.is_valid_username("abc-123")
  assert user_model.is_valid_username("a.b-c9")
  assert user_model.is_valid_username("aaa")
  assert user_model.is_valid_username("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
}

pub fn is_valid_username_rejects_invalid_values_test() {
  assert !user_model.is_valid_username("")
  assert !user_model.is_valid_username("ab")
  assert !user_model.is_valid_username(".abc")
  assert !user_model.is_valid_username("-abc")
  assert !user_model.is_valid_username("ab..cd")
  assert !user_model.is_valid_username("ab--cd")
  assert !user_model.is_valid_username("ab.-cd")
  assert !user_model.is_valid_username("ab-.cd")
  assert !user_model.is_valid_username("Abc")
  assert !user_model.is_valid_username("abc_123")
  assert !user_model.is_valid_username("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
}
