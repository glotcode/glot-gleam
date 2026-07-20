import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error

pub type Store {
  Store(delete_before: fn(Timestamp) -> Result(Nil, db_error.DbCommandError))
}
