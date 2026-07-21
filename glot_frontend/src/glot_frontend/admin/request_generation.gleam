/// Identifies the currently authoritative invocation of an asynchronous
/// request stream. The constructor is intentionally private so features cannot
/// compare or increment generations as unstructured integers.
pub opaque type Generation {
  Generation(Int)
}

pub fn initial() -> Generation {
  Generation(0)
}

pub fn next(generation: Generation) -> Generation {
  let Generation(value) = generation
  Generation(value + 1)
}

pub fn is_current(current: Generation, received: Generation) -> Bool {
  current == received
}
