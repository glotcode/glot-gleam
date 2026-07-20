import glot_backend/logging/api_log/adapter/postgres/store as api_log_store
import glot_backend/logging/page_log/adapter/postgres/store as page_log_store
import glot_backend/logging/pageview/adapter/postgres/store as pageview_store
import glot_backend/logging/ports
import glot_backend/logging/run_log/adapter/postgres/store as run_log_store
import glot_backend/system/database as db_helpers

pub fn new(db: db_helpers.Db) -> ports.Ports {
  ports.Ports(
    api_log: api_log_store.new(db),
    page_log: page_log_store.new(db),
    pageview: pageview_store.new(db),
    run_log: run_log_store.new(db),
  )
}
