import gleam/option
import glot_backend/logging/ports as logging_ports
import glot_backend/system/effect/cache_ports
import glot_backend/system/effect/database_ports
import glot_backend/system/effect/service_ports
import glot_backend/system/effect/system_ports as effect_system_ports
import support/integration/adapter/analytics
import support/integration/adapter/api_log
import support/integration/adapter/app_config
import support/integration/adapter/auth
import support/integration/adapter/email_template
import support/integration/adapter/job
import support/integration/adapter/page_log
import support/integration/adapter/pageview
import support/integration/adapter/run_log
import support/integration/adapter/snippet
import support/integration/adapter/state
import support/integration/adapter/system
import support/integration/adapter/transaction
import support/integration/adapter/user_action

pub fn defaults(test_state: state.State) -> service_ports.ServicePorts {
  let database =
    database_ports.fixed(
      app_config: app_config.default_store(),
      analytics: analytics.defaults(),
      email_template: email_template.defaults(),
      job: job.defaults(),
      logging: logging_ports.Ports(
        api_log: api_log.defaults(),
        page_log: page_log.defaults(),
        pageview: pageview.defaults(),
        run_log: run_log.defaults(),
      ),
      auth: auth.defaults(),
      snippet: snippet.defaults(),
      user_action: user_action.defaults(),
    )

  service_ports.ServicePorts(
    database: database,
    system: system.defaults(test_state),
    caches: cache_ports.without_caches(),
    transaction: transaction.new(test_state, database),
  )
}

pub fn with_app_config(
  services: service_ports.ServicePorts,
  test_state: state.State,
) -> service_ports.ServicePorts {
  let database =
    database_ports.with_app_config(
      services.database,
      app_config.store(test_state),
    )
  let services = with_database(services, test_state, database)
  service_ports.ServicePorts(
    ..services,
    caches: cache_ports.CachePorts(
      ..services.caches,
      app_config_cache: option.Some(app_config.cache(test_state)),
    ),
  )
}

pub fn with_auth(
  services: service_ports.ServicePorts,
  test_state: state.State,
) -> service_ports.ServicePorts {
  with_database(
    services,
    test_state,
    database_ports.with_auth(services.database, auth.new(test_state)),
  )
}

pub fn with_snippet(
  services: service_ports.ServicePorts,
  test_state: state.State,
) -> service_ports.ServicePorts {
  with_database(
    services,
    test_state,
    database_ports.with_snippet(services.database, snippet.new(test_state)),
  )
}

pub fn with_email_template(
  services: service_ports.ServicePorts,
  test_state: state.State,
) -> service_ports.ServicePorts {
  with_database(
    services,
    test_state,
    database_ports.with_email_template(
      services.database,
      email_template.new(test_state),
    ),
  )
}

pub fn with_job(
  services: service_ports.ServicePorts,
  test_state: state.State,
) -> service_ports.ServicePorts {
  with_database(
    services,
    test_state,
    database_ports.with_job(services.database, job.new(test_state)),
  )
}

pub fn with_user_action(
  services: service_ports.ServicePorts,
  test_state: state.State,
) -> service_ports.ServicePorts {
  with_database(
    services,
    test_state,
    database_ports.with_user_action(
      services.database,
      user_action.new(test_state),
    ),
  )
}

pub fn with_run_log(
  services: service_ports.ServicePorts,
  test_state: state.State,
) -> service_ports.ServicePorts {
  let logging =
    services.database
    |> database_ports.logging
    |> logging_ports.with_run_log(run_log.new(test_state))

  with_database(
    services,
    test_state,
    database_ports.with_logging(services.database, logging),
  )
}

pub fn with_system(
  services: service_ports.ServicePorts,
  ports: effect_system_ports.SystemPorts,
) -> service_ports.ServicePorts {
  service_ports.ServicePorts(..services, system: ports)
}

fn with_database(
  services: service_ports.ServicePorts,
  test_state: state.State,
  database: database_ports.DatabasePorts,
) -> service_ports.ServicePorts {
  service_ports.ServicePorts(
    ..services,
    database: database,
    transaction: transaction.new(test_state, database),
  )
}
