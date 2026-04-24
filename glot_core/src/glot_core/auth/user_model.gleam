import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/email/email_address_model
import youid/uuid.{type Uuid}

pub type UserRole {
  RegularUser
  AdminUser
}

pub type AccountState {
  Active
  ReadOnly
  Suspended
}

pub type AccountTier {
  FreeTier
}

pub type User {
  User(
    id: Uuid,
    email: email_address_model.EmailAddress,
    username: String,
    role: UserRole,
    account_state: AccountState,
    account_state_reason: option.Option(String),
    account_tier: AccountTier,
    last_login_at: Timestamp,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub fn mark_last_login(user: User, timestamp: Timestamp) -> User {
  User(..user, last_login_at: timestamp, updated_at: timestamp)
}

pub fn change_username(user: User, username: String, timestamp: Timestamp) -> User {
  User(..user, username: username, updated_at: timestamp)
}

pub fn role_to_string(role: UserRole) -> String {
  case role {
    RegularUser -> "user"
    AdminUser -> "admin"
  }
}

pub fn role_from_string(role: String) -> option.Option(UserRole) {
  case role {
    "user" -> option.Some(RegularUser)
    "admin" -> option.Some(AdminUser)
    _ -> option.None
  }
}

pub fn account_state_to_string(account_state: AccountState) -> String {
  case account_state {
    Active -> "active"
    ReadOnly -> "read_only"
    Suspended -> "suspended"
  }
}

pub fn account_state_from_string(
  account_state: String,
) -> option.Option(AccountState) {
  case account_state {
    "active" -> option.Some(Active)
    "read_only" -> option.Some(ReadOnly)
    "suspended" -> option.Some(Suspended)
    _ -> option.None
  }
}

pub fn account_tier_to_string(account_tier: AccountTier) -> String {
  case account_tier {
    FreeTier -> "free"
  }
}

pub fn account_tier_from_string(
  account_tier: String,
) -> option.Option(AccountTier) {
  case account_tier {
    "free" -> option.Some(FreeTier)
    _ -> option.None
  }
}

pub fn is_valid_username(username: String) -> Bool {
  let chars = username |> string.to_graphemes()
  let length = list.length(chars)

  case length < 3 || length > 40 {
    True -> False
    False -> validate_username_chars(chars, False, True)
  }
}

fn validate_username_chars(
  chars: List(String),
  previous_was_separator: Bool,
  is_first: Bool,
) -> Bool {
  case chars {
    [] -> True
    [char, ..rest] -> {
      let is_separator = char == "." || char == "-"
      let is_valid_char =
        is_separator || is_lowercase_letter(char) || is_digit(char)
      let invalid_start = is_first && is_separator
      let repeated_separator = previous_was_separator && is_separator

      case is_valid_char && !invalid_start && !repeated_separator {
        True -> validate_username_chars(rest, is_separator, False)
        False -> False
      }
    }
  }
}

fn is_lowercase_letter(char: String) -> Bool {
  list.contains(
    [
      "a",
      "b",
      "c",
      "d",
      "e",
      "f",
      "g",
      "h",
      "i",
      "j",
      "k",
      "l",
      "m",
      "n",
      "o",
      "p",
      "q",
      "r",
      "s",
      "t",
      "u",
      "v",
      "w",
      "x",
      "y",
      "z",
    ],
    char,
  )
}

fn is_digit(char: String) -> Bool {
  list.contains(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], char)
}
