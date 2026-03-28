import gleam/crypto
import gleam/int
import gleam/list
import gleam/string

const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"

pub fn new_token(length: Int) -> String {
  case length <= 0 {
    True -> ""
    False ->
      crypto.strong_random_bytes(length)
      |> random_bytes_to_token([], length)
  }
}

fn random_bytes_to_token(
  bytes: BitArray,
  acc: List(String),
  remaining_length: Int,
) -> String {
  case remaining_length, bytes {
    0, _ -> acc |> list.reverse |> string.concat
    _, <<byte, rest:bytes>> -> {
      let assert Ok(index) = int.modulo(byte, by: string.length(alphabet))
      random_bytes_to_token(rest, [alphabet_char(index), ..acc], remaining_length - 1)
    }
    _, _ -> acc |> list.reverse |> string.concat
  }
}

fn alphabet_char(index: Int) -> String {
  string.slice(alphabet, at_index: index, length: 1)
}
