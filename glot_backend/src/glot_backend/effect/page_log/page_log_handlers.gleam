import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error/db_error
import glot_backend/helpers/db_helpers
import glot_backend/sql

pub type PageLogHandlers {
  PageLogHandlers(
    delete_before: fn(Timestamp) -> Result(Nil, db_error.DbCommandError),
  )
}

pub fn new(db: db_helpers.Db) -> PageLogHandlers {
  PageLogHandlers(delete_before: fn(before) { delete_before(db, before) })
}

pub fn delete_before(
  db: db_helpers.Db,
  before: Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_page_log_before(before), to_error)
  |> result.map(fn(_) { Nil })
}
