import gleam/list
import gleam/string
import gleeunit
import glot_backend/crypto_token

const alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn new_token_length_test() {
  let token = crypto_token.new_token(64, crypto_token.AlphaNumeric)
  assert string.length(token) == 64
}

pub fn new_token_uses_alphanumeric_alphabet_test() {
  let token = crypto_token.new_token(256, crypto_token.AlphaNumeric)

  assert token
    |> string.to_utf_codepoints
    |> list.all(fn(char) {
      alphabet
      |> string.contains(string.from_utf_codepoints([char]))
    })
}

pub fn new_token_handles_non_positive_lengths_test() {
  assert crypto_token.new_token(0, crypto_token.AlphaNumeric) == ""
  assert crypto_token.new_token(-5, crypto_token.AlphaNumeric) == ""
}
