import glot_backend/auth/adapter/postgres/session/read
import glot_backend/auth/adapter/postgres/session/write
import glot_backend/auth/ports/session_store
import glot_backend/system/database as db_helpers

pub fn new(db: db_helpers.Db) -> session_store.SessionStore {
  session_store.SessionStore(
    list_by_user_id: fn(user_id, created_since, last_activity_since) {
      read.list_by_user_id(db, user_id, created_since, last_activity_since)
    },
    get_by_token: fn(is_email, token) { read.get_by_token(db, is_email, token) },
    get_by_token_for_update: fn(token) {
      read.get_by_token_for_update(db, token)
    },
    get_by_previous_token: fn(is_email, token) {
      read.get_by_previous_token(db, is_email, token)
    },
    get_by_previous_token_for_update: fn(token) {
      read.get_by_previous_token_for_update(db, token)
    },
    create: fn(session) { write.create(db, session) },
    update: fn(session) { write.update(db, session) },
    delete: fn(id) { write.delete(db, id) },
    delete_by_account_id: fn(id) { write.delete_by_account_id(db, id) },
    delete_expired: fn(created_before, last_activity_before) {
      write.delete_expired(db, created_before, last_activity_before)
    },
  )
}
