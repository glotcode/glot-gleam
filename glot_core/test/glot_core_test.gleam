import gleam/option
import gleam/time/timestamp
import gleeunit
import glot_core/auth/user_model
import glot_core/pagination_model
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

pub fn pagination_validate_accepts_valid_limit_test() {
  assert pagination_model.validate(
    pagination_model.InitialPage(limit: 10),
    100,
  ) == Ok(Nil)
}

pub fn pagination_validate_rejects_zero_limit_test() {
  assert pagination_model.validate(
    pagination_model.InitialPage(limit: 0),
    100,
  ) == Error("limit must be greater than 0")
}

pub fn pagination_validate_rejects_limit_above_max_test() {
  assert pagination_model.validate(
    pagination_model.InitialPage(limit: 101),
    100,
  ) == Error("limit must be less than or equal to 100")
}

pub fn paginate_initial_page_test() {
  let page =
    pagination_model.paginate(
      ["a", "b", "c"],
      pagination_model.InitialPage(limit: 2),
      pagination_model.from_string,
    )

  assert page
    == pagination_model.InitialCursorPage(
      items: ["a", "b"],
      next_cursor: option.Some(pagination_model.from_string("b")),
    )
}

pub fn paginate_after_page_test() {
  let page =
    pagination_model.paginate(
      ["c", "d", "e"],
      pagination_model.AfterPage(
        cursor: pagination_model.from_string("b"),
        limit: 2,
      ),
      pagination_model.from_string,
    )

  assert page
    == pagination_model.AfterCursorPage(
      items: ["c", "d"],
      previous_cursor: pagination_model.from_string("c"),
      next_cursor: option.Some(pagination_model.from_string("d")),
    )
}

pub fn paginate_before_page_test() {
  let page =
    pagination_model.paginate(
      ["a", "b", "c"],
      pagination_model.BeforePage(
        cursor: pagination_model.from_string("d"),
        limit: 2,
      ),
      pagination_model.from_string,
    )

  assert page
    == pagination_model.BeforeCursorPage(
      items: ["a", "b"],
      previous_cursor: option.Some(pagination_model.from_string("a")),
      next_cursor: pagination_model.from_string("b"),
    )
}

pub fn paginate_empty_after_page_reuses_request_cursor_test() {
  let page =
    pagination_model.paginate(
      [],
      pagination_model.AfterPage(
        cursor: pagination_model.from_string("x"),
        limit: 2,
      ),
      pagination_model.from_string,
    )

  assert page
    == pagination_model.AfterCursorPage(
      items: [],
      previous_cursor: pagination_model.from_string("x"),
      next_cursor: option.None,
    )
}

pub fn paginate_empty_before_page_reuses_request_cursor_test() {
  let page =
    pagination_model.paginate(
      [],
      pagination_model.BeforePage(
        cursor: pagination_model.from_string("x"),
        limit: 2,
      ),
      pagination_model.from_string,
    )

  assert page
    == pagination_model.BeforeCursorPage(
      items: [],
      previous_cursor: option.None,
      next_cursor: pagination_model.from_string("x"),
    )
}
