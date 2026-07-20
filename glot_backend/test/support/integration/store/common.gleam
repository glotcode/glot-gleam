import support/integration/model
import youid/uuid

pub fn pop_uuid(db: model.TestState) -> #(uuid.Uuid, model.TestState) {
  case db.next_uuids {
    [next, ..rest] -> #(next, model.TestState(..db, next_uuids: rest))
    [] -> #(uuid.nil, db)
  }
}

pub fn uuid_key(id: uuid.Uuid) -> String {
  uuid.to_string(id)
}
