pub type RequestTracker {
  RequestTracker(
    started: fn() -> Nil,
    finished: fn() -> Nil,
    count: fn() -> Int,
  )
}
