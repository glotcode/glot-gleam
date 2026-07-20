import gleam/crypto
import gleam/int
import gleam/list
import gleam/string

pub fn new_token(length: Int, alphabet: Alphabet) -> String {
  case length <= 0 {
    True -> ""
    False ->
      crypto.strong_random_bytes(length)
      |> random_bytes_to_token([], length, alphabet_data(alphabet))
  }
}

fn random_bytes_to_token(
  bytes: BitArray,
  acc: List(String),
  remaining_length: Int,
  alphabet: AlphabetData,
) -> String {
  case remaining_length, bytes {
    0, _ -> acc |> list.reverse |> string.concat
    _, <<byte, rest:bytes>> -> {
      let assert Ok(index) = int.modulo(byte, by: alphabet.length)
      random_bytes_to_token(
        rest,
        [alphabet_char(alphabet.chars, index), ..acc],
        remaining_length - 1,
        alphabet,
      )
    }
    _, _ -> acc |> list.reverse |> string.concat
  }
}

fn alphabet_char(chars: String, index: Int) -> String {
  string.slice(chars, at_index: index, length: 1)
}

pub type Alphabet {
  AlphaNumeric
  Numeric
}

fn alphabet_data(alphabet: Alphabet) -> AlphabetData {
  case alphabet {
    AlphaNumeric -> {
      let chars =
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
      AlphabetData(chars: chars, length: string.length(chars))
    }
    Numeric -> {
      let chars = "0123456789"
      AlphabetData(chars: chars, length: string.length(chars))
    }
  }
}

type AlphabetData {
  AlphabetData(chars: String, length: Int)
}
