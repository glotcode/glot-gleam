import gleam/dict
import gleam/erlang/process
import gleam/option
import glot_backend/worker/cache_worker_support

pub type Single(value, reply, meta) {
  Single(
    cache_entry: option.Option(cache_worker_support.CacheEntry(value)),
    in_flight: option.Option(cache_worker_support.InFlight(reply, meta)),
  )
}

pub type Keyed(key, value, reply, meta) {
  Keyed(
    cache_entries: dict.Dict(key, cache_worker_support.CacheEntry(value)),
    in_flights: dict.Dict(key, cache_worker_support.InFlight(reply, meta)),
  )
}

pub fn new_single() -> Single(value, reply, meta) {
  Single(cache_entry: option.None, in_flight: option.None)
}

pub fn new_keyed() -> Keyed(key, value, reply, meta) {
  Keyed(cache_entries: dict.new(), in_flights: dict.new())
}

pub fn single_lookup(
  state: Single(cached, reply, meta),
  reply: process.Subject(reply),
  now_ns: Int,
  refresh_interval_ms: Int,
  can_fetch: Bool,
  on_cache_hit: fn(cached) -> immediate,
  on_miss_unavailable: immediate,
  default_meta: meta,
) -> #(
  Single(cached, reply, meta),
  cache_worker_support.LookupDecision(reply, immediate, meta),
) {
  let Single(cache_entry:, in_flight:) = state

  case
    cache_worker_support.single_lookup(
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
  {
    cache_worker_support.ReplyNow(immediate, start_refresh) -> #(
      state,
      cache_worker_support.ReplyNow(immediate, start_refresh),
    )
    cache_worker_support.AwaitFetch(in_flight, start_fetch) -> #(
      Single(..state, in_flight: option.Some(in_flight)),
      cache_worker_support.AwaitFetch(in_flight, start_fetch),
    )
  }
}

pub fn keyed_lookup(
  state: Keyed(key, cached, reply, meta),
  key: key,
  reply: process.Subject(reply),
  now_ns: Int,
  refresh_interval_ms: Int,
  can_fetch: Bool,
  on_cache_hit: fn(cached) -> immediate,
  on_miss_unavailable: immediate,
  default_meta: meta,
) -> #(
  Keyed(key, cached, reply, meta),
  cache_worker_support.LookupDecision(reply, immediate, meta),
) {
  let Keyed(cache_entries:, in_flights:) = state

  case
    cache_worker_support.keyed_lookup(
      cache_entries,
      in_flights,
      key,
      reply,
      now_ns,
      refresh_interval_ms,
      can_fetch,
      on_cache_hit,
      on_miss_unavailable,
      default_meta,
    )
  {
    cache_worker_support.ReplyNow(immediate, start_refresh) -> #(
      state,
      cache_worker_support.ReplyNow(immediate, start_refresh),
    )
    cache_worker_support.AwaitFetch(in_flight, start_fetch) -> {
      let next_state =
        Keyed(
          ..state,
          in_flights: cache_worker_support.put_keyed_in_flight(
            in_flights,
            key,
            in_flight,
          ),
        )
      #(next_state, cache_worker_support.AwaitFetch(in_flight, start_fetch))
    }
  }
}

pub fn ensure_single_fetch_if_idle(
  state: Single(value, reply, meta),
  default_meta: meta,
) -> #(Single(value, reply, meta), Bool) {
  let Single(in_flight:, ..) = state
  let #(next_in_flight, should_start_fetch) =
    cache_worker_support.ensure_in_flight(in_flight, default_meta)

  #(Single(..state, in_flight: next_in_flight), should_start_fetch)
}

pub fn ensure_single_fetch_with_waiter(
  state: Single(value, reply, meta),
  reply: process.Subject(reply),
  default_meta: meta,
) -> #(Single(value, reply, meta), Bool) {
  let Single(in_flight:, ..) = state
  let #(next_in_flight, should_start_fetch) =
    cache_worker_support.ensure_in_flight_with_waiter(
      in_flight,
      reply,
      default_meta,
    )

  #(Single(..state, in_flight: next_in_flight), should_start_fetch)
}

pub fn single_is_stale(
  state: Single(value, reply, meta),
  now_ns: Int,
  refresh_interval_ms: Int,
) -> Bool {
  case single_cache_entry(state) {
    option.Some(cache_entry) ->
      cache_worker_support.is_stale(cache_entry, now_ns, refresh_interval_ms)
    option.None -> True
  }
}

pub fn single_cache_entry(
  state: Single(value, reply, meta),
) -> option.Option(cache_worker_support.CacheEntry(value)) {
  let Single(cache_entry:, ..) = state
  cache_entry
}

pub fn single_in_flight(
  state: Single(value, reply, meta),
) -> option.Option(cache_worker_support.InFlight(reply, meta)) {
  let Single(in_flight:, ..) = state
  in_flight
}

pub fn finish_single_fetch(
  state: Single(value, reply, meta),
  fetched_at_ns: Int,
  result: Result(value, err),
  default_meta: meta,
) -> #(
  Single(value, reply, meta),
  cache_worker_support.FetchOutcome(value, reply, err),
) {
  let Single(cache_entry:, in_flight:) = state
  let outcome =
    cache_worker_support.finish_single_fetch(
      in_flight,
      fetched_at_ns,
      result,
      default_meta,
    )

  let next_cache_entry = case outcome.cache_entry {
    option.Some(cache_entry) -> option.Some(cache_entry)
    option.None -> cache_entry
  }

  #(Single(cache_entry: next_cache_entry, in_flight: option.None), outcome)
}

pub fn finish_keyed_fetch(
  state: Keyed(key, value, reply, meta),
  key: key,
  fetched_at_ns: Int,
  result: Result(value, err),
  default_meta: meta,
) -> #(
  Keyed(key, value, reply, meta),
  cache_worker_support.FetchOutcome(value, reply, err),
) {
  let Keyed(cache_entries:, in_flights:) = state
  let outcome =
    cache_worker_support.finish_keyed_fetch(
      in_flights,
      key,
      fetched_at_ns,
      result,
      default_meta,
    )

  let next_cache_entries = case outcome.cache_entry {
    option.Some(cache_entry) -> dict.insert(cache_entries, key, cache_entry)
    option.None -> cache_entries
  }

  #(
    Keyed(
      cache_entries: next_cache_entries,
      in_flights: dict.delete(in_flights, key),
    ),
    outcome,
  )
}

pub fn keyed_cache_entries(
  state: Keyed(key, value, reply, meta),
) -> dict.Dict(key, cache_worker_support.CacheEntry(value)) {
  let Keyed(cache_entries:, ..) = state
  cache_entries
}

pub fn keyed_cache_entry(
  state: Keyed(key, value, reply, meta),
  key: key,
) -> option.Option(cache_worker_support.CacheEntry(value)) {
  let Keyed(cache_entries:, ..) = state
  case dict.get(cache_entries, key) {
    Ok(entry) -> option.Some(entry)
    Error(_) -> option.None
  }
}

pub fn keyed_in_flights(
  state: Keyed(key, value, reply, meta),
) -> dict.Dict(key, cache_worker_support.InFlight(reply, meta)) {
  let Keyed(in_flights:, ..) = state
  in_flights
}

pub fn put_keyed_in_flight(
  state: Keyed(key, value, reply, meta),
  key: key,
  in_flight: cache_worker_support.InFlight(reply, meta),
) -> Keyed(key, value, reply, meta) {
  let Keyed(in_flights:, ..) = state

  Keyed(
    ..state,
    in_flights: cache_worker_support.put_keyed_in_flight(
      in_flights,
      key,
      in_flight,
    ),
  )
}

pub fn prepare_keyed_fetch(
  state: Keyed(key, value, reply, meta),
  key: key,
  default_meta: meta,
  update_meta: fn(meta) -> meta,
) -> Keyed(key, value, reply, meta) {
  let existing_in_flight = keyed_in_flight(state, key, default_meta)
  let next_in_flight =
    cache_worker_support.InFlight(
      waiters: existing_in_flight.waiters,
      meta: update_meta(existing_in_flight.meta),
    )

  put_keyed_in_flight(state, key, next_in_flight)
}

pub fn ensure_keyed_fetch_if_idle(
  state: Keyed(key, value, reply, meta),
  key: key,
  default_meta: meta,
  update_meta: fn(meta) -> meta,
) -> #(Keyed(key, value, reply, meta), Bool) {
  case has_keyed_in_flight(state, key) {
    True -> #(state, False)
    False -> #(prepare_keyed_fetch(state, key, default_meta, update_meta), True)
  }
}

pub fn keyed_in_flight(
  state: Keyed(key, value, reply, meta),
  key: key,
  default_meta: meta,
) -> cache_worker_support.InFlight(reply, meta) {
  let Keyed(in_flights:, ..) = state
  cache_worker_support.keyed_in_flight(in_flights, key, default_meta)
}

pub fn has_keyed_in_flight(
  state: Keyed(key, value, reply, meta),
  key: key,
) -> Bool {
  let Keyed(in_flights:, ..) = state
  dict.has_key(in_flights, key)
}

pub fn keyed_is_empty(state: Keyed(key, value, reply, meta)) -> Bool {
  let Keyed(cache_entries:, in_flights:) = state
  dict.is_empty(cache_entries) && dict.is_empty(in_flights)
}

pub fn keyed_is_stale_or_missing(
  state: Keyed(key, value, reply, meta),
  key: key,
  now_ns: Int,
  refresh_interval_ms: Int,
) -> Bool {
  case keyed_cache_entry(state, key) {
    option.Some(cache_entry) ->
      cache_worker_support.is_stale(cache_entry, now_ns, refresh_interval_ms)
    option.None -> True
  }
}
