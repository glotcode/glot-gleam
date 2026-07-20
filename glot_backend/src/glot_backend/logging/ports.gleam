import glot_backend/logging/api_log/ports/store as api_log_store
import glot_backend/logging/page_log/ports/store as page_log_store
import glot_backend/logging/pageview/ports/store as pageview_store
import glot_backend/logging/run_log/ports/store as run_log_store

pub type Ports {
  Ports(
    api_log: api_log_store.Store,
    page_log: page_log_store.Store,
    pageview: pageview_store.Store,
    run_log: run_log_store.Store,
  )
}

pub fn with_run_log(ports: Ports, run_log: run_log_store.Store) -> Ports {
  Ports(..ports, run_log: run_log)
}
