import gleam/option.{type Option}
import glot_backend/system/effect/service_ports

pub type Runtime {
  Runtime(services: service_ports.ServicePorts)
}

pub fn new(services: service_ports.ServicePorts) -> Runtime {
  Runtime(services: services)
}

pub fn with_timeout(runtime: Runtime, timeout_ms: Option(Int)) -> Runtime {
  Runtime(services: service_ports.with_database_timeout(
    runtime.services,
    timeout_ms,
  ))
}
