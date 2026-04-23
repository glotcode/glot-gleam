import gleam/list
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/email/email_address_model
import youid/uuid.{type Uuid}

pub type User {
  User(
    id: Uuid,
    email: email_address_model.EmailAddress,
    username: String,
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
