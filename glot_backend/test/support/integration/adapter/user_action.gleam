import glot_backend/user_action/ports/store
import support/integration/adapter/state
import support/integration/adapter/unexpected
import support/integration/store/user_action

pub fn defaults() -> store.Store {
  store.Store(
    count: fn(_) { unexpected.query("user_action.count") },
    create: fn(_) { unexpected.command("user_action.create") },
    delete_before: fn(_) { unexpected.command("user_action.delete_before") },
  )
}

pub fn new(test_state: state.State) -> store.Store {
  store.Store(
    count: fn(_) { Ok([]) },
    create: fn(_) {
      state.update(test_state, user_action.increment_user_action_count)
      Ok(Nil)
    },
    delete_before: fn(before) {
      state.update(test_state, fn(db) {
        user_action.delete_user_actions_before(db, before)
      })
      Ok(Nil)
    },
  )
}
