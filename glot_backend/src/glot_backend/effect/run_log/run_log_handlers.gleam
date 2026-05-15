import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/language
import glot_core/run_log_model
import youid/uuid

pub type RunLogHandlers {
  RunLogHandlers(
    create_run_log: fn(run_log_model.RunLog) ->
      Result(Nil, error.DbCommandError),
    delete_before: fn(Timestamp) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: db_helpers.Db) -> RunLogHandlers {
  RunLogHandlers(
    create_run_log: fn(run_log) { create_run_log(db, run_log) },
    delete_before: fn(before) { delete_before(db, before) },
  )
}

pub fn create_run_log(
  db: db_helpers.Db,
  run_log: run_log_model.RunLog,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_run_log(
      id: uuid.to_bit_array(run_log.id),
      request_id: uuid.to_bit_array(run_log.request_id),
      created_at: run_log.created_at,
      session_id: option.map(run_log.session_id, uuid.to_bit_array),
      user_id: option.map(run_log.user_id, uuid.to_bit_array),
      language: language.to_string(run_log.language),
      outcome: run_log_model.run_outcome_to_string(run_log.outcome),
      duration_ns: run_log.duration_ns,
      failure_message: run_log.failure_message,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_before(
  db: db_helpers.Db,
  before: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_run_log_before(before), to_error)
  |> result.map(fn(_) { Nil })
}
