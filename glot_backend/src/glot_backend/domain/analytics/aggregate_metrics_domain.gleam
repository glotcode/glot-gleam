import gleam/option
import gleam/order
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import glot_backend/context
import glot_backend/effect/analytics/analytics_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/transaction/transaction_program

pub fn aggregate_metrics(
  ctx: context.Context,
) -> program_types.Program(Nil) {
  let #(today, _) = calendar_date(ctx.timestamp)

  use maybe_next_day <- program.and_then(next_metrics_day(today))
  case maybe_next_day {
    option.None -> program.succeed(Nil)
    option.Some(day) ->
      case calendar.naive_date_compare(day, today) {
        order.Lt -> transaction_effect.run(aggregate_day_tx(day))
        _ -> program.succeed(Nil)
      }
  }
}

fn next_metrics_day(
  today: calendar.Date,
) -> program_types.Program(option.Option(calendar.Date)) {
  use maybe_max_completed_day <- program.and_then(
    analytics_effect.get_max_completed_metrics_day(),
  )

  case maybe_max_completed_day {
    option.Some(day) -> program.succeed(option.Some(add_days(day, 1)))
    option.None -> analytics_effect.get_first_metrics_source_day(today)
  }
}

fn aggregate_day_tx(
  day: calendar.Date,
) -> program_types.TransactionProgram(Nil) {
  transaction_program.sequence([
    analytics_effect.insert_metrics_pageview_day_tx(day),
    analytics_effect.insert_metrics_product_event_day_tx(day),
    analytics_effect.insert_metrics_run_day_tx(day),
    analytics_effect.insert_metrics_reliability_page_day_tx(day),
    analytics_effect.insert_metrics_reliability_api_day_tx(day),
    analytics_effect.insert_metrics_completed_day_tx(day),
  ])
}

fn calendar_date(
  ts: timestamp.Timestamp,
) -> #(calendar.Date, calendar.TimeOfDay) {
  timestamp.to_calendar(ts, calendar.utc_offset)
}

fn add_days(
  day: calendar.Date,
  days: Int,
) -> calendar.Date {
  let midnight =
    calendar.TimeOfDay(hours: 0, minutes: 0, seconds: 0, nanoseconds: 0)
  let #(next_day, _) =
    timestamp.from_calendar(day, midnight, calendar.utc_offset)
    |> timestamp.add(duration.seconds(days * 86_400))
    |> timestamp.to_calendar(calendar.utc_offset)

  next_day
}
