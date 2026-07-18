pub type CacheOutcome {
  CacheHit
  StaleCacheHit
  CacheMissFetched
  CacheMissJoined
  CacheUnavailable
}

pub fn to_string(outcome: CacheOutcome) -> String {
  case outcome {
    CacheHit -> "hit"
    StaleCacheHit -> "stale_hit"
    CacheMissFetched -> "miss_fetched"
    CacheMissJoined -> "miss_joined"
    CacheUnavailable -> "unavailable"
  }
}
