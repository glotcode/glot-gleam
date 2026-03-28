import gleam/list
import gleam/string
import gleeunit
import glot_backend/crypto_helpers

const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn new_token_length_test() {
  let token = crypto_helpers.new_token(64)
  assert string.length(token) == 64
}

pub fn new_token_uses_lowercase_alphanumeric_alphabet_test() {
  let token = crypto_helpers.new_token(256)

  assert token
    |> string.to_utf_codepoints
    |> list.all(fn(char) {
      alphabet
      |> string.contains(
        string.from_utf_codepoints([char]),
      )
    })
}

pub fn new_token_handles_non_positive_lengths_test() {
  assert crypto_helpers.new_token(0) == ""
  assert crypto_helpers.new_token(-5) == ""
}
