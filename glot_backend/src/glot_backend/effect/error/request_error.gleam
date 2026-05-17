import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/string
import glot_core/rate_limit.{type RateLimit}
import glot_core/validation_error

pub type RequestError {
  JsonParseError(json.DecodeError)
  DecodeError(List(decode.DecodeError))
  Validation(validation_error.ValidationError)
  TooManyRequests(count: Int, rate_limit: RateLimit)
}

pub fn status(err: RequestError) -> Int {
  case err {
    TooManyRequests(_, _) -> 429
    _ -> 400
  }
}

pub fn code(err: RequestError) -> String {
  case err {
    JsonParseError(_) -> "json_parse_error"
    DecodeError(_) -> "decode_error"
    Validation(validation) -> validation_code(validation)
    TooManyRequests(_, _) -> "too_many_requests"
  }
}

pub fn message(err: RequestError) -> String {
  case err {
    JsonParseError(parse_error) ->
      "Decode error: " <> string.inspect(parse_error)
    DecodeError(errors) -> "Decode error: " <> string.inspect(errors)
    Validation(validation) -> validation_message(validation)
    TooManyRequests(count, config) ->
      "Too many requests: "
      <> int.to_string(count)
      <> " / "
      <> int.to_string(config.max_requests)
  }
}

pub fn to_string(err: RequestError) -> String {
  case err {
    JsonParseError(parse_error) -> "parse_error:" <> string.inspect(parse_error)
    DecodeError(errors) -> "decode_error:" <> string.inspect(errors)
    Validation(validation) ->
      "validation_error:" <> validation_message(validation)
    TooManyRequests(count, _) -> "too_many_requests:" <> int.to_string(count)
  }
}

pub fn validation_message(err: validation_error.ValidationError) -> String {
  validation_error.message(err)
}

fn validation_code(err: validation_error.ValidationError) -> String {
  validation_error.code(err)
}
