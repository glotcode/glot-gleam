import gleam/option.{type Option}
import glot_backend/effect/handlers
import pog

pub type Runtime {
  Runtime(connection: Option(pog.Connection), handlers: handlers.Handlers)
}

pub fn new(connection: pog.Connection) -> Runtime {
  Runtime(
    connection: option.Some(connection),
    handlers: handlers.new(connection),
  )
}

pub fn from_handlers(handlers: handlers.Handlers) -> Runtime {
  Runtime(connection: option.None, handlers: handlers)
}

pub fn with_connection(_runtime: Runtime, connection: pog.Connection) -> Runtime {
  Runtime(
    connection: option.Some(connection),
    handlers: handlers.new(connection),
  )
}
