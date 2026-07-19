import gleam/option
import gleam/regexp
import gleeunit
import glot_core/email/email_address_model
import glot_core/route
import glot_frontend/account_page
import glot_frontend/contact_page
import glot_frontend/delayed_loading
import glot_frontend/login_page
import glot_frontend/snippets_page
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

pub fn delayed_loading_only_reveals_current_generation_test() {
  let #(first_load, _) =
    delayed_loading.start(delayed_loading.idle(), fn(id) { id })
  let #(second_load, _) = delayed_loading.start(first_load, fn(id) { id })

  assert !delayed_loading.is_visible(first_load)
  assert !delayed_loading.is_visible(delayed_loading.reveal(second_load, 1))
  assert delayed_loading.is_visible(delayed_loading.reveal(second_load, 2))
  assert !delayed_loading.is_visible(delayed_loading.finish(second_load))
}

pub fn snippets_page_ignores_loading_timer_from_previous_route_test() {
  let #(first_model, _) =
    snippets_page.init(
      after: option.Some("first"),
      before: option.None,
      username: option.None,
    )
  let snippets_page.Model(request: first_request, ..) = first_model
  let #(second_model, _) =
    snippets_page.init(
      after: option.Some("second"),
      before: option.None,
      username: option.None,
    )

  let #(model_after_old_timer, _) =
    snippets_page.update(
      second_model,
      snippets_page.LoadingDelayElapsed(first_request, 1),
    )
  let snippets_page.Model(loading_indicator:, ..) = model_after_old_timer

  assert !delayed_loading.is_visible(loading_indicator)
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

pub fn contact_page_prefills_empty_email_test() {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  let assert option.Some(email) =
    email_address_model.from_string(is_email, "user@example.com")
  let #(model, _) = contact_page.init(option.None)
  let contact_page.Model(email:, ..) =
    contact_page.session_loaded(model, option.Some(email))

  assert email == "user@example.com"
}

pub fn contact_page_does_not_replace_entered_email_test() {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  let assert option.Some(email) =
    email_address_model.from_string(is_email, "user@example.com")
  let #(model, _) = contact_page.init(option.None)
  let #(model, _) =
    contact_page.update(model, contact_page.EmailChanged("other@example.com"))
  let contact_page.Model(email:, ..) =
    contact_page.session_loaded(model, option.Some(email))

  assert email == "other@example.com"
}

pub fn contact_page_initializes_with_authenticated_email_test() {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  let assert option.Some(email) =
    email_address_model.from_string(is_email, "user@example.com")
  let #(contact_page.Model(email:, ..), _) =
    contact_page.init(option.Some(email))

  assert email == "user@example.com"
}
