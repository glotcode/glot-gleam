import glot_backend/effect/handlers
import pog

pub type Runtime {
  Runtime(handlers: handlers.Handlers)
}

pub fn new(connection: pog.Connection) -> Runtime {
  Runtime(handlers: handlers.new(connection))
}

pub fn from_handlers(handlers: handlers.Handlers) -> Runtime {
  Runtime(handlers: handlers)
}
