import gleam/time/timestamp.{type Timestamp}
import glot_backend/crypto_token
import glot_core/helpers/uuid_helpers
import youid/uuid.{type Uuid}

pub type BasicHandlers {
  BasicHandlers(
    new_token: fn(Int, crypto_token.Alphabet) -> String,
    system_time: fn() -> Timestamp,
    uuid_v7: fn(Timestamp) -> Uuid,
  )
}

pub fn new() -> BasicHandlers {
  BasicHandlers(
    new_token: new_token,
    system_time: system_time,
    uuid_v7: uuid_v7,
  )
}

pub fn new_token(length: Int, alphabet: crypto_token.Alphabet) -> String {
  crypto_token.new_token(length, alphabet)
}

pub fn system_time() -> Timestamp {
  timestamp.system_time()
}

pub fn uuid_v7(now: Timestamp) -> Uuid {
  uuid_helpers.v7(now)
}
