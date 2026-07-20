import glot_backend/auth/adapter/postgres/user/read
import glot_backend/auth/adapter/postgres/user/write
import glot_backend/auth/ports/user_store
import glot_backend/system/database as db_helpers

pub fn new(db: db_helpers.Db) -> user_store.UserStore {
  user_store.UserStore(
    get_by_email: fn(is_email, email) { read.get_by_email(db, is_email, email) },
    get_by_id: fn(is_email, id) { read.get_by_id(db, is_email, id) },
    list: fn(is_email, pagination, filters) {
      read.list(db, is_email, pagination, filters)
    },
    create: fn(user) { write.create(db, user) },
    update: fn(user) { write.update(db, user) },
    delete_by_account_id: fn(id) { write.delete_by_account_id(db, id) },
  )
}
