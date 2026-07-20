import gleam/option
import gleam/regexp
import glot_backend/auth/model/user_list_filters.{type UserListFilters}
import glot_backend/system/effect/error/db_error
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/pagination_model.{type CursorPagination}
import youid/uuid.{type Uuid}

pub type UserStore {
  UserStore(
    get_by_email: fn(regexp.Regexp, email_address_model.EmailAddress) ->
      Result(option.Option(user_model.HydratedUser), db_error.DbQueryError),
    get_by_id: fn(regexp.Regexp, Uuid) ->
      Result(option.Option(user_model.HydratedUser), db_error.DbQueryError),
    list: fn(regexp.Regexp, CursorPagination, UserListFilters) ->
      Result(List(user_model.HydratedUser), db_error.DbQueryError),
    create: fn(user_model.User) -> Result(Nil, db_error.DbCommandError),
    update: fn(user_model.User) -> Result(Nil, db_error.DbCommandError),
    delete_by_account_id: fn(Uuid) -> Result(Nil, db_error.DbCommandError),
  )
}
