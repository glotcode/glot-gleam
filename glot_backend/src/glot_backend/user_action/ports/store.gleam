import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error
import glot_core/rate_limit.{type WindowCount}
import glot_core/user_action.{type UserAction, type UserActionFilter}

pub type Store {
  Store(
    count: fn(UserActionFilter) ->
      Result(List(WindowCount), db_error.DbQueryError),
    create: fn(UserAction) -> Result(Nil, db_error.DbCommandError),
    delete_before: fn(Timestamp) -> Result(Nil, db_error.DbCommandError),
  )
}
