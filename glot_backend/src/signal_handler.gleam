import gleam/erlang/process.{type Name}

@external(erlang, "signal_handler_ffi", "install")
pub fn install(signal_name: Name(message)) -> Nil
