import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option

pub type CacheEntry(value) {
  CacheEntry(value: value, refreshed_at_ns: Int)
}

pub type InFlight(reply, meta) {
  InFlight(waiters: List(process.Subject(reply)), meta: meta)
}

pub type LookupDecision(reply, immediate, meta) {
  ReplyNow(immediate: immediate, start_refresh: Bool)
  AwaitFetch(in_flight: InFlight(reply, meta), start_fetch: Bool)
}

pub fn new_in_flight(meta: meta) -> InFlight(reply, meta) {
  InFlight(waiters: [], meta: meta)
}

pub fn with_waiter(
  in_flight: InFlight(reply, meta),
  reply: process.Subject(reply),
) -> InFlight(reply, meta) {
  InFlight(
    waiters: [reply, ..in_flight.waiters],
    meta: in_flight.meta,
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

pub fn reply_waiters(
  waiters: List(process.Subject(reply)),
  result: reply,
) -> Nil {
  list.each(waiters, fn(reply) { process.send(reply, result) })
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
    option.Some(entry) ->
      ReplyNow(
        immediate: on_cache_hit(entry.value),
        start_refresh: is_stale(entry, now_ns, refresh_interval_ms),
      )
    option.None ->
      case in_flight {
        option.Some(in_flight) ->
          AwaitFetch(with_waiter(in_flight, reply), start_fetch: False)
        option.None ->
          case can_fetch {
            True ->
              AwaitFetch(
                new_in_flight(default_meta)
                |> with_waiter(reply),
                start_fetch: True,
              )
            False -> ReplyNow(on_miss_unavailable, start_refresh: False)
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
