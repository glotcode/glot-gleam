import gleam/option.{type Option}
import glot_backend/analytics/ports/store as analytics_store
import glot_backend/app_config/ports/store as app_config_store
import glot_backend/auth/ports as auth_ports
import glot_backend/email/ports/template_store
import glot_backend/job/ports as job_ports
import glot_backend/logging/ports as logging_ports
import glot_backend/snippet/ports/store as snippet_store
import glot_backend/user_action/ports/store as user_action_store

pub opaque type DatabasePorts {
  DatabasePorts(
    timeout_ms: Option(Int),
    app_config: fn(Option(Int)) -> app_config_store.Store,
    analytics: fn(Option(Int)) -> analytics_store.Store,
    email_template: fn(Option(Int)) -> template_store.TemplateStore,
    job: fn(Option(Int)) -> job_ports.Ports,
    logging: fn(Option(Int)) -> logging_ports.Ports,
    auth: fn(Option(Int)) -> auth_ports.Ports,
    snippet: fn(Option(Int)) -> snippet_store.Store,
    user_action: fn(Option(Int)) -> user_action_store.Store,
  )
}

pub fn new(
  app_config app_config: fn(Option(Int)) -> app_config_store.Store,
  analytics analytics: fn(Option(Int)) -> analytics_store.Store,
  email_template email_template: fn(Option(Int)) -> template_store.TemplateStore,
  job job: fn(Option(Int)) -> job_ports.Ports,
  logging logging: fn(Option(Int)) -> logging_ports.Ports,
  auth auth: fn(Option(Int)) -> auth_ports.Ports,
  snippet snippet: fn(Option(Int)) -> snippet_store.Store,
  user_action user_action: fn(Option(Int)) -> user_action_store.Store,
) -> DatabasePorts {
  DatabasePorts(
    timeout_ms: option.None,
    app_config: app_config,
    analytics: analytics,
    email_template: email_template,
    job: job,
    logging: logging,
    auth: auth,
    snippet: snippet,
    user_action: user_action,
  )
}

pub fn fixed(
  app_config app_config: app_config_store.Store,
  analytics analytics: analytics_store.Store,
  email_template email_template: template_store.TemplateStore,
  job job: job_ports.Ports,
  logging logging: logging_ports.Ports,
  auth auth: auth_ports.Ports,
  snippet snippet: snippet_store.Store,
  user_action user_action: user_action_store.Store,
) -> DatabasePorts {
  new(
    app_config: fn(_) { app_config },
    analytics: fn(_) { analytics },
    email_template: fn(_) { email_template },
    job: fn(_) { job },
    logging: fn(_) { logging },
    auth: fn(_) { auth },
    snippet: fn(_) { snippet },
    user_action: fn(_) { user_action },
  )
}

pub fn with_timeout(
  ports: DatabasePorts,
  timeout_ms: Option(Int),
) -> DatabasePorts {
  DatabasePorts(..ports, timeout_ms: timeout_ms)
}

pub fn with_auth(
  ports: DatabasePorts,
  auth: auth_ports.Ports,
) -> DatabasePorts {
  DatabasePorts(..ports, auth: fn(_) { auth })
}

pub fn with_snippet(
  ports: DatabasePorts,
  snippet: snippet_store.Store,
) -> DatabasePorts {
  DatabasePorts(..ports, snippet: fn(_) { snippet })
}

pub fn with_email_template(
  ports: DatabasePorts,
  email_template: template_store.TemplateStore,
) -> DatabasePorts {
  DatabasePorts(..ports, email_template: fn(_) { email_template })
}

pub fn with_job(ports: DatabasePorts, job: job_ports.Ports) -> DatabasePorts {
  DatabasePorts(..ports, job: fn(_) { job })
}

pub fn with_logging(
  ports: DatabasePorts,
  logging: logging_ports.Ports,
) -> DatabasePorts {
  DatabasePorts(..ports, logging: fn(_) { logging })
}

pub fn with_user_action(
  ports: DatabasePorts,
  user_action: user_action_store.Store,
) -> DatabasePorts {
  DatabasePorts(..ports, user_action: fn(_) { user_action })
}

pub fn with_app_config(
  ports: DatabasePorts,
  app_config: app_config_store.Store,
) -> DatabasePorts {
  DatabasePorts(..ports, app_config: fn(_) { app_config })
}

pub fn app_config(ports: DatabasePorts) -> app_config_store.Store {
  ports.app_config(ports.timeout_ms)
}

pub fn logging(ports: DatabasePorts) -> logging_ports.Ports {
  ports.logging(ports.timeout_ms)
}

pub fn analytics(ports: DatabasePorts) -> analytics_store.Store {
  ports.analytics(ports.timeout_ms)
}

pub fn email_template(ports: DatabasePorts) -> template_store.TemplateStore {
  ports.email_template(ports.timeout_ms)
}

pub fn job(ports: DatabasePorts) -> job_ports.Ports {
  ports.job(ports.timeout_ms)
}

pub fn auth(ports: DatabasePorts) -> auth_ports.Ports {
  ports.auth(ports.timeout_ms)
}

pub fn snippet(ports: DatabasePorts) -> snippet_store.Store {
  ports.snippet(ports.timeout_ms)
}

pub fn user_action(ports: DatabasePorts) -> user_action_store.Store {
  ports.user_action(ports.timeout_ms)
}
