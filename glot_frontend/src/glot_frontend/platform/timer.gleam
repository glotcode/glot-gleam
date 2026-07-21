@external(javascript, "./timer_ffi.mjs", "schedule")
pub fn schedule(milliseconds: Int, callback: fn() -> Nil) -> Nil
