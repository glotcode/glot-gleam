import gleam/option
import gleeunit
import glot_core/route
import glot_frontend/string_helpers

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  let name = "Joe"
  let greeting = "Hello, " <> name <> "!"

  assert greeting == "Hello, Joe!"
}

pub fn truncate_stem_middle_keeps_short_strings_test() {
  assert string_helpers.truncate_stem_middle("short", 10) == "short"
}

pub fn truncate_stem_middle_truncates_to_requested_length_test() {
  assert string_helpers.truncate_stem_middle("verylongname", 10) == "very...ame"
  assert string_helpers.truncate_stem_middle("abcdefghijklmnopqrstu", 20)
    == "abcdefghi...nopqrstu"
}

pub fn truncate_stem_middle_handles_tiny_lengths_test() {
  assert string_helpers.truncate_stem_middle("abcdef", 4) == "abcd"
  assert string_helpers.truncate_stem_middle("abcdef", 2) == "ab"
}

pub fn snippets_route_to_string_includes_username_query_test() {
  assert route.to_string(route.Public(route.Snippets(
      after: option.Some("after-1"),
      before: option.None,
      username: option.Some("alice"),
    )))
    == "/snippets?after=after-1&username=alice"
}

pub fn admin_rate_limits_route_to_string_test() {
  assert route.to_string(route.Admin(route.AdminRateLimits))
    == "/admin/rate-limits"
}

pub fn admin_route_to_string_test() {
  assert route.to_string(route.Admin(route.AdminHome)) == "/admin"
}

pub fn admin_config_route_to_string_test() {
  assert route.to_string(route.Admin(route.AdminConfig)) == "/admin/config"
}
