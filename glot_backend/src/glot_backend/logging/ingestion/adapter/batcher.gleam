import gleam/result
import glot_backend/logging/ingestion/ports/batch_store.{type BatchStore}
import glot_backend/logging/ingestion/ports/config_provider.{type ConfigProvider}
import glot_backend/logging/ingestion/worker/batcher/worker
import glot_backend/system/effect/error/db_error
import wisp

pub fn new(
  config_provider: ConfigProvider,
  batch_store: BatchStore,
) -> worker.Deps {
  worker.Deps(
    load_config: config_provider.load,
    insert_batch: fn(entries) {
      batch_store.insert(entries)
      |> result.map_error(db_error.transaction_to_string)
    },
    log_error: wisp.log_error,
  )
}
