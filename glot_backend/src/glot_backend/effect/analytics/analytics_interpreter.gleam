import glot_backend/effect/analytics/analytics_algebra
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: analytics_algebra.AnalyticsEffect(next_program),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    analytics_algebra.GetMaxCompletedMetricsDay(next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.analytics.get_max_completed_metrics_day()
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AnalyticsEffectName(
            analytics_algebra.GetMaxCompletedMetricsDayEffectName,
          ),
          effect_trace.DbReadEffectCategory,
          started_at,
        ),
      )
    }
    analytics_algebra.GetFirstMetricsSourceDay(before:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.analytics.get_first_metrics_source_day(before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AnalyticsEffectName(
            analytics_algebra.GetFirstMetricsSourceDayEffectName,
          ),
          effect_trace.DbReadEffectCategory,
          started_at,
        ),
      )
    }
    analytics_algebra.InsertMetricsPageviewDay(day:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.analytics.insert_metrics_pageview_day(day)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AnalyticsEffectName(
            analytics_algebra.InsertMetricsPageviewDayEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    analytics_algebra.InsertMetricsProductEventDay(day:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.analytics.insert_metrics_product_event_day(day)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AnalyticsEffectName(
            analytics_algebra.InsertMetricsProductEventDayEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    analytics_algebra.InsertMetricsRunDay(day:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.analytics.insert_metrics_run_day(day)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AnalyticsEffectName(
            analytics_algebra.InsertMetricsRunDayEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    analytics_algebra.InsertMetricsReliabilityPageDay(day:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.analytics.insert_metrics_reliability_page_day(day)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AnalyticsEffectName(
            analytics_algebra.InsertMetricsReliabilityPageDayEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    analytics_algebra.InsertMetricsReliabilityApiDay(day:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.analytics.insert_metrics_reliability_api_day(day)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AnalyticsEffectName(
            analytics_algebra.InsertMetricsReliabilityApiDayEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    analytics_algebra.InsertMetricsCompletedDay(day:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.analytics.insert_metrics_completed_day(day)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AnalyticsEffectName(
            analytics_algebra.InsertMetricsCompletedDayEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
