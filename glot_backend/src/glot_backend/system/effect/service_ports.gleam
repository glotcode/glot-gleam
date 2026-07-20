import gleam/option.{type Option}
import glot_backend/system/effect/cache_ports.{type CachePorts}
import glot_backend/system/effect/database_ports.{type DatabasePorts}
import glot_backend/system/effect/system_ports.{type SystemPorts}
import glot_backend/system/effect/transaction/transaction_port.{
  type TransactionPort,
}

pub type ServicePorts {
  ServicePorts(
    database: DatabasePorts,
    system: SystemPorts,
    caches: CachePorts,
    transaction: TransactionPort,
  )
}

pub fn with_database_timeout(
  services: ServicePorts,
  timeout_ms: Option(Int),
) -> ServicePorts {
  ServicePorts(
    ..services,
    database: database_ports.with_timeout(services.database, timeout_ms),
  )
}
