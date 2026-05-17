import gleam/option
import gleam/result
import gleam/string
import gleam/time/calendar
import glot_backend/effect/error/db_error
import glot_backend/helpers/db_helpers
import glot_backend/sql

pub type AnalyticsHandlers {
  AnalyticsHandlers(
    get_max_completed_metrics_day: fn() ->
      Result(option.Option(calendar.Date), db_error.DbQueryError),
    get_first_metrics_source_day: fn(calendar.Date) ->
      Result(option.Option(calendar.Date), db_error.DbQueryError),
    insert_metrics_pageview_day: fn(calendar.Date) ->
      Result(Nil, db_error.DbCommandError),
    insert_metrics_product_event_day: fn(calendar.Date) ->
      Result(Nil, db_error.DbCommandError),
    insert_metrics_run_day: fn(calendar.Date) ->
      Result(Nil, db_error.DbCommandError),
    insert_metrics_reliability_page_day: fn(calendar.Date) ->
      Result(Nil, db_error.DbCommandError),
    insert_metrics_reliability_api_day: fn(calendar.Date) ->
      Result(Nil, db_error.DbCommandError),
    insert_metrics_completed_day: fn(calendar.Date) ->
      Result(Nil, db_error.DbCommandError),
  )
}

pub fn new(db: db_helpers.Db) -> AnalyticsHandlers {
  AnalyticsHandlers(
    get_max_completed_metrics_day: fn() { get_max_completed_metrics_day(db) },
    get_first_metrics_source_day: fn(before) {
      get_first_metrics_source_day(db, before)
    },
    insert_metrics_pageview_day: fn(day) {
      insert_metrics_pageview_day(db, day)
    },
    insert_metrics_product_event_day: fn(day) {
      insert_metrics_product_event_day(db, day)
    },
    insert_metrics_run_day: fn(day) { insert_metrics_run_day(db, day) },
    insert_metrics_reliability_page_day: fn(day) {
      insert_metrics_reliability_page_day(db, day)
    },
    insert_metrics_reliability_api_day: fn(day) {
      insert_metrics_reliability_api_day(db, day)
    },
    insert_metrics_completed_day: fn(day) {
      insert_metrics_completed_day(db, day)
    },
  )
}

pub fn get_max_completed_metrics_day(
  db: db_helpers.Db,
) -> Result(option.Option(calendar.Date), db_error.DbQueryError) {
  let to_error = fn(err) { db_error.DbQueryError(string.inspect(err)) }
  use returned <- result.try(db_helpers.query(
    db,
    sql.get_max_completed_metrics_day(),
    to_error,
  ))

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> Ok(option.Some(row.day))
    _ ->
      Error(db_error.DbQueryError("Expected one max completed metrics day row"))
  }
}

pub fn get_first_metrics_source_day(
  db: db_helpers.Db,
  before: calendar.Date,
) -> Result(option.Option(calendar.Date), db_error.DbQueryError) {
  let to_error = fn(err) { db_error.DbQueryError(string.inspect(err)) }
  use returned <- result.try(db_helpers.query(
    db,
    sql.get_first_metrics_source_day(before_day: before),
    to_error,
  ))

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> Ok(option.Some(row.day))
    _ ->
      Error(db_error.DbQueryError("Expected one first metrics source day row"))
  }
}

pub fn insert_metrics_pageview_day(
  db: db_helpers.Db,
  day: calendar.Date,
) -> Result(Nil, db_error.DbCommandError) {
  execute_rollup(db, sql.insert_metrics_pageview_day(day))
}

pub fn insert_metrics_product_event_day(
  db: db_helpers.Db,
  day: calendar.Date,
) -> Result(Nil, db_error.DbCommandError) {
  execute_rollup(db, sql.insert_metrics_product_event_day(day))
}

pub fn insert_metrics_run_day(
  db: db_helpers.Db,
  day: calendar.Date,
) -> Result(Nil, db_error.DbCommandError) {
  execute_rollup(db, sql.insert_metrics_run_day(day))
}

pub fn insert_metrics_reliability_page_day(
  db: db_helpers.Db,
  day: calendar.Date,
) -> Result(Nil, db_error.DbCommandError) {
  execute_rollup(db, sql.insert_metrics_reliability_page_day(day))
}

pub fn insert_metrics_reliability_api_day(
  db: db_helpers.Db,
  day: calendar.Date,
) -> Result(Nil, db_error.DbCommandError) {
  execute_rollup(db, sql.insert_metrics_reliability_api_day(day))
}

pub fn insert_metrics_completed_day(
  db: db_helpers.Db,
  day: calendar.Date,
) -> Result(Nil, db_error.DbCommandError) {
  execute_rollup(db, sql.insert_metrics_completed_day(day))
}

fn execute_rollup(
  db: db_helpers.Db,
  query: db_helpers.ExecuteParams,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }
  db_helpers.execute(db, query, to_error)
  |> result.map(fn(_) { Nil })
}
