@external(erlang, "os", "perf_counter")
pub fn perf_counter(_resolution: Int) -> Int {
  panic as "not implemented"
}

pub fn perf_counter_ns() -> Int {
  perf_counter(1_000_000_000)
}
