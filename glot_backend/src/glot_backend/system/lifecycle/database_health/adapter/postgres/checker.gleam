import gleam/dynamic/decode
import gleam/result
import gleam/string
import glot_backend/system/database as db_helpers
import glot_backend/system/lifecycle/database_health/ports/checker.{type Checker}
import pog

pub fn new(db: pog.Connection) -> Checker {
  checker.Checker(check: fn() { health_check(db) })
}

fn health_check(db: pog.Connection) -> Result(Nil, String) {
  pog.query("SELECT 1")
  |> pog.timeout(db_helpers.default_query_timeout_ms())
  |> pog.returning(ping_decoder())
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(string.inspect)
}

fn ping_decoder() -> decode.Decoder(Int) {
  use value <- decode.field(0, decode.int)
  decode.success(value)
}
