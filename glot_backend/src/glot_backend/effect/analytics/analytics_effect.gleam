import gleam/option.{type Option}
import gleam/time/calendar.{type Date}
import glot_backend/effect/analytics/analytics_algebra
import glot_backend/effect/error
import glot_backend/effect/program_types

pub fn get_max_completed_metrics_day() -> program_types.Program(Option(Date)) {
  program_types.Impure(
    program_types.DbEffect(
      program_types.AnalyticsEffect(
        analytics_algebra.GetMaxCompletedMetricsDay(next: query_next),
      ),
    ),
  )
}

pub fn get_first_metrics_source_day(
  before: Date,
) -> program_types.Program(Option(Date)) {
  program_types.Impure(
    program_types.DbEffect(
      program_types.AnalyticsEffect(analytics_algebra.GetFirstMetricsSourceDay(
        before: before,
        next: query_next,
      )),
    ),
  )
}

pub fn insert_metrics_pageview_day(day: Date) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(insert_metrics_pageview_day_effect(day, next)),
  )
}

pub fn insert_metrics_product_event_day(
  day: Date,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(insert_metrics_product_event_day_effect(day, next)),
  )
}

pub fn insert_metrics_run_day(day: Date) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(insert_metrics_run_day_effect(day, next)),
  )
}

pub fn insert_metrics_reliability_page_day(
  day: Date,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(insert_metrics_reliability_page_day_effect(day, next)),
  )
}

pub fn insert_metrics_reliability_api_day(
  day: Date,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(insert_metrics_reliability_api_day_effect(day, next)),
  )
}

pub fn insert_metrics_pageview_day_tx(
  day: Date,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(insert_metrics_pageview_day_effect(day, tx_next))
}

pub fn insert_metrics_product_event_day_tx(
  day: Date,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(insert_metrics_product_event_day_effect(day, tx_next))
}

pub fn insert_metrics_run_day_tx(
  day: Date,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(insert_metrics_run_day_effect(day, tx_next))
}

pub fn insert_metrics_reliability_page_day_tx(
  day: Date,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(
    insert_metrics_reliability_page_day_effect(day, tx_next),
  )
}

pub fn insert_metrics_reliability_api_day_tx(
  day: Date,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(
    insert_metrics_reliability_api_day_effect(day, tx_next),
  )
}

pub fn insert_metrics_completed_day_tx(
  day: Date,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(insert_metrics_completed_day_effect(day, tx_next))
}

fn next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}

fn tx_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.TransactionProgram(Nil) {
  case result {
    Ok(_) -> program_types.TxPure(Nil)
    Error(err) -> program_types.TxFail(error.CommandError(err))
  }
}

fn query_next(
  result: Result(Option(Date), error.DbQueryError),
) -> program_types.Program(Option(Date)) {
  case result {
    Ok(value) -> program_types.Pure(value)
    Error(err) -> program_types.Fail(error.QueryError(err))
  }
}

fn insert_metrics_pageview_day_effect(
  day: Date,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AnalyticsEffect(analytics_algebra.InsertMetricsPageviewDay(
    day: day,
    next: next,
  ))
}

fn insert_metrics_product_event_day_effect(
  day: Date,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AnalyticsEffect(
    analytics_algebra.InsertMetricsProductEventDay(day: day, next: next),
  )
}

fn insert_metrics_run_day_effect(
  day: Date,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AnalyticsEffect(analytics_algebra.InsertMetricsRunDay(
    day: day,
    next: next,
  ))
}

fn insert_metrics_reliability_page_day_effect(
  day: Date,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AnalyticsEffect(
    analytics_algebra.InsertMetricsReliabilityPageDay(day: day, next: next),
  )
}

fn insert_metrics_reliability_api_day_effect(
  day: Date,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AnalyticsEffect(
    analytics_algebra.InsertMetricsReliabilityApiDay(day: day, next: next),
  )
}

fn insert_metrics_completed_day_effect(
  day: Date,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AnalyticsEffect(analytics_algebra.InsertMetricsCompletedDay(
    day: day,
    next: next,
  ))
}
