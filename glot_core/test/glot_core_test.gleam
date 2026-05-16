import gleam/option
import gleam/time/timestamp
import gleeunit
import glot_core/admin_action
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_core/helpers/timestamp_helpers
import glot_core/language
import glot_core/pagination_model
import glot_core/public_action
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

pub fn account_tier_round_trips_free_plus_test() {
  assert account_model.account_tier_to_string(account_model.FreePlusTier)
    == "free_plus"
  assert account_model.account_tier_from_string("free_plus")
    == option.Some(account_model.FreePlusTier)
}

pub fn public_action_from_string_round_trips_test() {
  public_action.list()
  |> assert_action_round_trips(
    public_action.to_string,
    public_action.from_string,
  )
}

pub fn public_action_from_string_rejects_admin_and_unknown_values_test() {
  assert public_action.from_string("get_admin_debug_config") == option.None
  assert public_action.from_string("not_a_real_action") == option.None
}

pub fn admin_action_from_string_round_trips_test() {
  admin_action.list()
  |> assert_action_round_trips(admin_action.to_string, admin_action.from_string)
}

pub fn admin_action_from_string_rejects_public_and_unknown_values_test() {
  assert admin_action.from_string("run") == option.None
  assert admin_action.from_string("not_a_real_action") == option.None
}

pub fn api_action_from_string_round_trips_test() {
  api_action.list()
  |> assert_action_round_trips(api_action.to_string, api_action.from_string)
}

pub fn api_action_from_string_wraps_public_and_admin_actions_test() {
  assert api_action.from_string("run")
    == option.Some(api_action.public(public_action.RunAction))
  assert api_action.from_string("get_admin_debug_config")
    == option.Some(api_action.admin(admin_action.GetAdminDebugConfigAction))
}

pub fn api_action_from_string_rejects_unknown_values_test() {
  assert api_action.from_string("not_a_real_action") == option.None
}

pub fn validate_username_accepts_valid_values_test() {
  assert user_model.validate_username("abc") == Ok(Nil)
  assert user_model.validate_username("abc-123") == Ok(Nil)
  assert user_model.validate_username("a.b-c9") == Ok(Nil)
  assert user_model.validate_username("aaa") == Ok(Nil)
  assert user_model.validate_username(
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    )
    == Ok(Nil)
}

pub fn validate_username_rejects_invalid_values_test() {
  let error =
    Error(
      "Invalid username: use 3-40 lowercase letters, digits, dots, or hyphens",
    )

  assert user_model.validate_username("") == error
  assert user_model.validate_username("ab") == error
  assert user_model.validate_username(".abc") == error
  assert user_model.validate_username("-abc") == error
  assert user_model.validate_username("ab..cd") == error
  assert user_model.validate_username("ab--cd") == error
  assert user_model.validate_username("ab.-cd") == error
  assert user_model.validate_username("ab-.cd") == error
  assert user_model.validate_username("Abc") == error
  assert user_model.validate_username("abc_123") == error
  assert user_model.validate_username(
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    )
    == error
}

pub fn validate_snippet_fields_rejects_empty_files_test() {
  assert snippet_model.validate_fields("Snippet", "", option.None, [])
    == Error("files must contain at least one file")
}

pub fn validate_snippet_fields_rejects_empty_title_test() {
  assert snippet_model.validate_fields("   ", "", option.None, [
      snippet_model.File(name: "main.py", content: "print(1)"),
    ])
    == Error("title must not be empty")
}

pub fn validate_snippet_fields_rejects_empty_file_name_test() {
  assert snippet_model.validate_fields("Snippet", "", option.None, [
      snippet_model.File(name: "  ", content: "print(1)"),
    ])
    == Error("files[0].name must not be empty")
}

pub fn validate_snippet_fields_rejects_empty_run_command_test() {
  assert snippet_model.validate_fields(
      "Snippet",
      "",
      option.Some(language.RunInstructions(build_commands: [], run_command: " ")),
      [snippet_model.File(name: "main.py", content: "print(1)")],
    )
    == Error("runInstructions.runCommand must not be empty")
}

pub fn validate_snippet_fields_rejects_empty_build_command_test() {
  assert snippet_model.validate_fields(
      "Snippet",
      "",
      option.Some(language.RunInstructions(
        build_commands: [" "],
        run_command: "python main.py",
      )),
      [snippet_model.File(name: "main.py", content: "print(1)")],
    )
    == Error("runInstructions.buildCommands[0] must not be empty")
}

pub fn cobol_example_code_preserves_fixed_format_indentation_test() {
  assert language.example_code(language.Cobol)
    == "       IDENTIFICATION DIVISION.
       PROGRAM-ID. hello.

       PROCEDURE DIVISION.
           DISPLAY 'Hello World!'
           GOBACK
           ."
}

pub fn validate_snippet_fields_rejects_too_long_title_test() {
  assert snippet_model.validate_fields(
      repeat_string("a", 201),
      "",
      option.None,
      [snippet_model.File(name: "main.py", content: "print(1)")],
    )
    == Error("title must be at most 200 characters")
}

pub fn validate_snippet_fields_rejects_too_long_file_content_test() {
  assert snippet_model.validate_fields("Snippet", "", option.None, [
      snippet_model.File(name: "main.py", content: repeat_string("a", 100_001)),
    ])
    == Error("files[0].content must be at most 100000 characters")
}

pub fn pagination_validate_accepts_valid_limit_test() {
  assert pagination_model.validate(pagination_model.InitialPage(limit: 10), 100)
    == Ok(Nil)
}

pub fn pagination_validate_rejects_zero_limit_test() {
  assert pagination_model.validate(pagination_model.InitialPage(limit: 0), 100)
    == Error("limit must be greater than 0")
}

pub fn pagination_validate_rejects_limit_above_max_test() {
  assert pagination_model.validate(
      pagination_model.InitialPage(limit: 101),
      100,
    )
    == Error("limit must be less than or equal to 100")
}

pub fn timestamp_relative_label_for_past_test() {
  let now = timestamp.from_unix_seconds_and_nanoseconds(3600, 0)
  let created_at = timestamp.from_unix_seconds_and_nanoseconds(3300, 0)

  assert timestamp_helpers.relative_label(created_at, now) == "5 minutes ago"
}

pub fn timestamp_relative_label_for_future_test() {
  let now = timestamp.from_unix_seconds_and_nanoseconds(3600, 0)
  let scheduled_at = timestamp.from_unix_seconds_and_nanoseconds(10_800, 0)

  assert timestamp_helpers.relative_label(scheduled_at, now) == "in 2 hours"
}

pub fn timestamp_from_unix_milliseconds_test() {
  let ts = timestamp_helpers.from_unix_milliseconds(1_234_567_890)

  assert timestamp.to_unix_seconds_and_nanoseconds(ts)
    == #(1_234_567, 890_000_000)
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
      ["c", "b", "a"],
      pagination_model.BeforePage(
        cursor: pagination_model.from_string("d"),
        limit: 2,
      ),
      pagination_model.from_string,
    )

  assert page
    == pagination_model.BeforeCursorPage(
      items: ["b", "a"],
      previous_cursor: option.Some(pagination_model.from_string("b")),
      next_cursor: pagination_model.from_string("a"),
    )
}

pub fn paginate_before_page_keeps_nearest_window_test() {
  let page =
    pagination_model.paginate(
      ["5", "4", "3"],
      pagination_model.BeforePage(
        cursor: pagination_model.from_string("2"),
        limit: 2,
      ),
      pagination_model.from_string,
    )

  assert page
    == pagination_model.BeforeCursorPage(
      items: ["4", "3"],
      previous_cursor: option.Some(pagination_model.from_string("4")),
      next_cursor: pagination_model.from_string("3"),
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

fn repeat_string(value: String, count: Int) -> String {
  case count <= 0 {
    True -> ""
    False -> value <> repeat_string(value, count - 1)
  }
}

fn assert_action_round_trips(
  actions: List(a),
  to_string: fn(a) -> String,
  from_string: fn(String) -> option.Option(a),
) -> Nil {
  case actions {
    [] -> Nil
    [first, ..rest] -> {
      assert from_string(to_string(first)) == option.Some(first)
      assert_action_round_trips(rest, to_string, from_string)
    }
  }
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
