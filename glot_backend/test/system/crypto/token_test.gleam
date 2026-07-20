import gleam/list
import gleam/string
import glot_backend/system/crypto/token

const alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

pub fn new_token_length_test() {
  let token = token.new_token(64, token.AlphaNumeric)
  assert string.length(token) == 64
}

pub fn new_token_uses_alphanumeric_alphabet_test() {
  let token = token.new_token(256, token.AlphaNumeric)

  assert token
    |> string.to_utf_codepoints
    |> list.all(fn(char) {
      alphabet
      |> string.contains(string.from_utf_codepoints([char]))
    })
}

pub fn new_token_handles_non_positive_lengths_test() {
  assert token.new_token(0, token.AlphaNumeric) == ""
  assert token.new_token(-5, token.AlphaNumeric) == ""
}
