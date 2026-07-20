import glot_backend/logging/ingestion/model/batch
import glot_backend/system/effect/error/db_error

pub type BatchStore {
  BatchStore(
    insert: fn(List(batch.Entry)) -> Result(Nil, db_error.DbTransactionError),
  )
}
