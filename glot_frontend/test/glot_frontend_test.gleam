import gleam/option
import gleam/regexp
import gleeunit
import glot_core/email/email_address_model
import glot_core/route
import glot_frontend/account_page
import glot_frontend/login_page
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
  assert route.to_string(
      route.Public(route.Snippets(
        after: option.Some("after-1"),
        before: option.None,
        username: option.Some("alice"),
      )),
    )
    == "/snippets?after=after-1&username=alice"
}

pub fn admin_rate_limits_route_to_string_test() {
  assert route.to_string(route.Admin(route.AdminRateLimits))
    == "/admin/rate-limits"
}

pub fn privacy_route_to_string_test() {
  assert route.to_string(route.Public(route.Privacy)) == "/privacy"
  assert route.to_string(route.Public(route.Contact)) == "/contact"
  assert route.name(route.Public(route.Privacy)) == "privacy"
  assert route.name(route.Public(route.Contact)) == "contact"
}

pub fn admin_route_to_string_test() {
  assert route.to_string(route.Admin(route.AdminHome)) == "/admin"
}

pub fn admin_config_route_to_string_test() {
  assert route.to_string(route.Admin(route.AdminConfig)) == "/admin/config"
}

pub fn login_page_email_submit_msg_uses_send_token_for_email_step_test() {
  assert login_page.email_submit_msg(login_page.EnterEmail)
    == login_page.SendTokenSubmitted
}

pub fn login_page_email_submit_msg_uses_login_for_token_step_test() {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  let assert option.Some(email) =
    email_address_model.from_string(is_email, "user@example.com")

  assert login_page.email_submit_msg(login_page.EnterToken(email))
    == login_page.LoginSubmitted
}

pub fn login_page_show_send_token_button_hides_after_token_sent_test() {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  let assert option.Some(email) =
    email_address_model.from_string(is_email, "user@example.com")

  assert login_page.show_send_token_button(login_page.EnterEmail)
  assert !login_page.show_send_token_button(login_page.EnterToken(email))
}

pub fn login_page_show_passkey_section_reflects_browser_support_test() {
  assert login_page.show_passkey_section(True)
  assert !login_page.show_passkey_section(False)
}

pub fn account_page_show_passkey_section_reflects_browser_support_test() {
  assert account_page.should_show_passkey_section(True)
  assert !account_page.should_show_passkey_section(False)
}
