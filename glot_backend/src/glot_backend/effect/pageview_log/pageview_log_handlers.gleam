import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import pog

pub type PageviewLogHandlers {
  PageviewLogHandlers(
    delete_before: fn(Timestamp) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> PageviewLogHandlers {
  PageviewLogHandlers(delete_before: fn(before) { delete_before(db, before) })
}

pub fn delete_before(
  db: pog.Connection,
  before: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_pageview_log_before(before), to_error)
  |> result.map(fn(_) { Nil })
}
