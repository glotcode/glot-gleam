import gleam/option
import glot_backend/analytics/adapter/postgres/store as analytics_postgres_store
import glot_backend/app_config/adapter/postgres/store as app_config_postgres_store
import glot_backend/auth/adapter/postgres/ports as auth_postgres_ports
import glot_backend/email/adapter/postgres/template_store as email_template_postgres_store
import glot_backend/job/adapter/postgres/ports as job_postgres_ports
import glot_backend/logging/adapter/postgres/ports as logging_postgres_ports
import glot_backend/snippet/adapter/postgres/store as snippet_postgres_store
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/database_ports
import glot_backend/user_action/adapter/postgres/store as user_action_postgres_store

pub fn new(db: db_helpers.Db) -> database_ports.DatabasePorts {
  database_ports.new(
    app_config: fn(timeout) {
      app_config_postgres_store.new(scoped(db, timeout))
    },
    analytics: fn(timeout) { analytics_postgres_store.new(scoped(db, timeout)) },
    email_template: fn(timeout) {
      email_template_postgres_store.new(scoped(db, timeout))
    },
    job: fn(timeout) { job_postgres_ports.new(scoped(db, timeout)) },
    logging: fn(timeout) { logging_postgres_ports.new(scoped(db, timeout)) },
    auth: fn(timeout) { auth_postgres_ports.new(scoped(db, timeout)) },
    snippet: fn(timeout) { snippet_postgres_store.new(scoped(db, timeout)) },
    user_action: fn(timeout) {
      user_action_postgres_store.new(scoped(db, timeout))
    },
  )
}

fn scoped(db: db_helpers.Db, timeout_ms: option.Option(Int)) -> db_helpers.Db {
  db_helpers.override_timeout(db, timeout_ms)
}
