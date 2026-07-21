import gleam/option
import gleam/string
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_frontend/admin/users/list_model.{type Model}
import youid/uuid

pub fn has_filters(model: Model) -> Bool {
  string.trim(model.search_filter) != ""
  || model.role_filter != ""
  || model.account_state_filter != ""
  || model.account_tier_filter != ""
}

pub fn email(value: String) -> option.Option(String) {
  let trimmed = string.trim(value)

  case string.contains(trimmed, "@") {
    True -> option.Some(trimmed)
    False -> option.None
  }
}

pub fn username(value: String) -> option.Option(String) {
  let trimmed = string.trim(value)

  case trimmed == "" || string.contains(trimmed, "@") {
    True -> option.None
    False ->
      case uuid.from_string(trimmed) {
        Ok(_) -> option.None
        Error(_) -> option.Some(trimmed)
      }
  }
}

pub fn user_id(value: String) -> option.Option(uuid.Uuid) {
  case uuid.from_string(string.trim(value)) {
    Ok(id) -> option.Some(id)
    Error(_) -> option.None
  }
}

pub fn role(value: String) -> option.Option(user_model.UserRole) {
  case string.trim(value) {
    "" -> option.None
    trimmed -> user_model.role_from_string(trimmed)
  }
}

pub fn account_state(
  value: String,
) -> option.Option(account_model.AccountState) {
  case string.trim(value) {
    "" -> option.None
    trimmed -> account_model.account_state_from_string(trimmed)
  }
}

pub fn account_tier(value: String) -> option.Option(account_model.AccountTier) {
  case string.trim(value) {
    "" -> option.None
    trimmed -> account_model.account_tier_from_string(trimmed)
  }
}
