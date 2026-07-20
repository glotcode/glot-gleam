pub type Tracker {
  Tracker(started: fn() -> Nil, finished: fn() -> Nil, count: fn() -> Int)
}
