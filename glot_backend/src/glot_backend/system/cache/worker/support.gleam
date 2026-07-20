import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option
import glot_backend/system/cache/cache_outcome.{type CacheOutcome}

pub type Lookup(value) {
  Lookup(value: value, outcome: CacheOutcome)
}

pub type CacheEntry(value) {
  CacheEntry(value: value, refreshed_at_ns: Int)
}

pub type Waiter(reply) {
  Waiter(reply_to: process.Subject(reply), outcome: CacheOutcome)
}

pub type InFlight(reply, meta) {
  InFlight(waiters: List(Waiter(reply)), meta: meta)
}

pub type LookupDecision(reply, immediate, meta) {
  ReplyNow(immediate: immediate, start_refresh: Bool, outcome: CacheOutcome)
  AwaitFetch(in_flight: InFlight(reply, meta), start_fetch: Bool)
}

pub type FetchOutcome(value, reply, err) {
  FetchOutcome(
    cache_entry: option.Option(CacheEntry(value)),
    waiters: List(Waiter(reply)),
    error: option.Option(err),
  )
}

pub fn new_in_flight(meta: meta) -> InFlight(reply, meta) {
  InFlight(waiters: [], meta: meta)
}

pub fn with_waiter(
  in_flight: InFlight(reply, meta),
  reply: process.Subject(reply),
) -> InFlight(reply, meta) {
  with_waiter_outcome(in_flight, reply, cache_outcome.CacheMissJoined)
}

fn with_waiter_outcome(
  in_flight: InFlight(reply, meta),
  reply: process.Subject(reply),
  outcome: CacheOutcome,
) -> InFlight(reply, meta) {
  InFlight(
    waiters: [Waiter(reply_to: reply, outcome: outcome), ..in_flight.waiters],
    meta: in_flight.meta,
  )
}

pub fn ensure_in_flight(
  in_flight: option.Option(InFlight(reply, meta)),
  default_meta: meta,
) -> #(option.Option(InFlight(reply, meta)), Bool) {
  case in_flight {
    option.Some(in_flight) -> #(option.Some(in_flight), False)
    option.None -> #(option.Some(new_in_flight(default_meta)), True)
  }
}

pub fn ensure_in_flight_with_waiter(
  in_flight: option.Option(InFlight(reply, meta)),
  reply: process.Subject(reply),
  default_meta: meta,
) -> #(option.Option(InFlight(reply, meta)), Bool) {
  let #(next_in_flight, should_start_fetch) =
    ensure_in_flight(in_flight, default_meta)

  let outcome = case should_start_fetch {
    True -> cache_outcome.CacheMissFetched
    False -> cache_outcome.CacheMissJoined
  }

  #(
    option.map(next_in_flight, fn(in_flight) {
      with_waiter_outcome(in_flight, reply, outcome)
    }),
    should_start_fetch,
  )
}

pub fn single_in_flight(
  in_flight: option.Option(InFlight(reply, meta)),
  default_meta: meta,
) -> InFlight(reply, meta) {
  case in_flight {
    option.Some(in_flight) -> in_flight
    option.None -> new_in_flight(default_meta)
  }
}

pub fn keyed_in_flight(
  in_flights: dict.Dict(key, InFlight(reply, meta)),
  key: key,
  default_meta: meta,
) -> InFlight(reply, meta) {
  case dict.get(in_flights, key) {
    Ok(in_flight) -> in_flight
    Error(_) -> new_in_flight(default_meta)
  }
}

pub fn put_keyed_in_flight(
  in_flights: dict.Dict(key, InFlight(reply, meta)),
  key: key,
  in_flight: InFlight(reply, meta),
) -> dict.Dict(key, InFlight(reply, meta)) {
  dict.insert(in_flights, key, in_flight)
}

pub fn reply_waiters(waiters: List(Waiter(reply)), result: reply) -> Nil {
  list.each(waiters, fn(waiter) { process.send(waiter.reply_to, result) })
}

pub fn single_lookup(
  cache_entry: option.Option(CacheEntry(cached)),
  in_flight: option.Option(InFlight(reply, meta)),
  reply: process.Subject(reply),
  now_ns: Int,
  refresh_interval_ms: Int,
  can_fetch: Bool,
  on_cache_hit: fn(cached) -> immediate,
  on_miss_unavailable: immediate,
  default_meta: meta,
) -> LookupDecision(reply, immediate, meta) {
  case cache_entry {
    option.Some(entry) -> {
      let stale = is_stale(entry, now_ns, refresh_interval_ms)
      ReplyNow(
        immediate: on_cache_hit(entry.value),
        start_refresh: stale,
        outcome: case stale {
          True -> cache_outcome.StaleCacheHit
          False -> cache_outcome.CacheHit
        },
      )
    }
    option.None ->
      case in_flight {
        option.Some(in_flight) ->
          AwaitFetch(
            with_waiter_outcome(in_flight, reply, cache_outcome.CacheMissJoined),
            start_fetch: False,
          )
        option.None ->
          case can_fetch {
            True ->
              AwaitFetch(
                new_in_flight(default_meta)
                  |> with_waiter_outcome(reply, cache_outcome.CacheMissFetched),
                start_fetch: True,
              )
            False ->
              ReplyNow(
                on_miss_unavailable,
                start_refresh: False,
                outcome: cache_outcome.CacheUnavailable,
              )
          }
      }
  }
}

pub fn keyed_lookup(
  cache_entries: dict.Dict(key, CacheEntry(cached)),
  in_flights: dict.Dict(key, InFlight(reply, meta)),
  key: key,
  reply: process.Subject(reply),
  now_ns: Int,
  refresh_interval_ms: Int,
  can_fetch: Bool,
  on_cache_hit: fn(cached) -> immediate,
  on_miss_unavailable: immediate,
  default_meta: meta,
) -> LookupDecision(reply, immediate, meta) {
  let cache_entry = case dict.get(cache_entries, key) {
    Ok(entry) -> option.Some(entry)
    Error(_) -> option.None
  }
  let in_flight = case dict.get(in_flights, key) {
    Ok(in_flight) -> option.Some(in_flight)
    Error(_) -> option.None
  }

  single_lookup(
    cache_entry,
    in_flight,
    reply,
    now_ns,
    refresh_interval_ms,
    can_fetch,
    on_cache_hit,
    on_miss_unavailable,
    default_meta,
  )
}

pub fn cache_result(
  fetched_at_ns: Int,
  result: Result(value, err),
) -> option.Option(CacheEntry(value)) {
  case result {
    Ok(value) -> option.Some(CacheEntry(value:, refreshed_at_ns: fetched_at_ns))
    Error(_) -> option.None
  }
}

pub fn finish_single_fetch(
  in_flight: option.Option(InFlight(reply, meta)),
  fetched_at_ns: Int,
  result: Result(value, err),
  default_meta: meta,
) -> FetchOutcome(value, reply, err) {
  let in_flight = single_in_flight(in_flight, default_meta)

  FetchOutcome(
    cache_entry: cache_result(fetched_at_ns, result),
    waiters: in_flight.waiters,
    error: result |> result_error(),
  )
}

pub fn finish_keyed_fetch(
  in_flights: dict.Dict(key, InFlight(reply, meta)),
  key: key,
  fetched_at_ns: Int,
  result: Result(value, err),
  default_meta: meta,
) -> FetchOutcome(value, reply, err) {
  let in_flight = keyed_in_flight(in_flights, key, default_meta)

  FetchOutcome(
    cache_entry: cache_result(fetched_at_ns, result),
    waiters: in_flight.waiters,
    error: result |> result_error(),
  )
}

pub fn fetch_outcome_waiters(
  outcome: FetchOutcome(value, reply, err),
) -> List(Waiter(reply)) {
  outcome.waiters
}

pub fn fetch_outcome_cache_entry(
  outcome: FetchOutcome(value, reply, err),
) -> option.Option(CacheEntry(value)) {
  outcome.cache_entry
}

pub fn is_stale(
  entry: CacheEntry(value),
  now_ns: Int,
  refresh_interval_ms: Int,
) -> Bool {
  now_ns - entry.refreshed_at_ns >= ms_to_ns(refresh_interval_ms)
}

pub fn ms_to_ns(value_ms: Int) -> Int {
  value_ms * 1_000_000
}

fn result_error(result: Result(value, err)) -> option.Option(err) {
  case result {
    Ok(_) -> option.None
    Error(err) -> option.Some(err)
  }
}
