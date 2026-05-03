import gleam/option.{type Option}
import gleam/time/calendar.{type Date}
import glot_backend/effect/error

pub type AnalyticsEffect(next) {
  GetMaxCompletedMetricsDay(
    next: fn(Result(Option(Date), error.DbQueryError)) -> next,
  )
  GetFirstMetricsSourceDay(
    before: Date,
    next: fn(Result(Option(Date), error.DbQueryError)) -> next,
  )
  InsertMetricsPageviewDay(
    day: Date,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  InsertMetricsProductEventDay(
    day: Date,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  InsertMetricsRunDay(
    day: Date,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  InsertMetricsReliabilityPageDay(
    day: Date,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  InsertMetricsReliabilityApiDay(
    day: Date,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  InsertMetricsCompletedDay(
    day: Date,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(
  effect: AnalyticsEffect(a),
  f: fn(a) -> b,
) -> AnalyticsEffect(b) {
  case effect {
    GetMaxCompletedMetricsDay(next:) ->
      GetMaxCompletedMetricsDay(next: fn(value) { f(next(value)) })
    GetFirstMetricsSourceDay(before:, next:) ->
      GetFirstMetricsSourceDay(
        before: before,
        next: fn(value) { f(next(value)) },
      )
    InsertMetricsPageviewDay(day:, next:) ->
      InsertMetricsPageviewDay(day: day, next: fn(value) { f(next(value)) })
    InsertMetricsProductEventDay(day:, next:) ->
      InsertMetricsProductEventDay(
        day: day,
        next: fn(value) { f(next(value)) },
      )
    InsertMetricsRunDay(day:, next:) ->
      InsertMetricsRunDay(day: day, next: fn(value) { f(next(value)) })
    InsertMetricsReliabilityPageDay(day:, next:) ->
      InsertMetricsReliabilityPageDay(
        day: day,
        next: fn(value) { f(next(value)) },
      )
    InsertMetricsReliabilityApiDay(day:, next:) ->
      InsertMetricsReliabilityApiDay(
        day: day,
        next: fn(value) { f(next(value)) },
      )
    InsertMetricsCompletedDay(day:, next:) ->
      InsertMetricsCompletedDay(day: day, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetMaxCompletedMetricsDayEffectName
  GetFirstMetricsSourceDayEffectName
  InsertMetricsPageviewDayEffectName
  InsertMetricsProductEventDayEffectName
  InsertMetricsRunDayEffectName
  InsertMetricsReliabilityPageDayEffectName
  InsertMetricsReliabilityApiDayEffectName
  InsertMetricsCompletedDayEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetMaxCompletedMetricsDayEffectName -> "get_max_completed_metrics_day"
    GetFirstMetricsSourceDayEffectName -> "get_first_metrics_source_day"
    InsertMetricsPageviewDayEffectName -> "insert_metrics_pageview_day"
    InsertMetricsProductEventDayEffectName -> "insert_metrics_product_event_day"
    InsertMetricsRunDayEffectName -> "insert_metrics_run_day"
    InsertMetricsReliabilityPageDayEffectName ->
      "insert_metrics_reliability_page_day"
    InsertMetricsReliabilityApiDayEffectName ->
      "insert_metrics_reliability_api_day"
    InsertMetricsCompletedDayEffectName -> "insert_metrics_completed_day"
  }
}
