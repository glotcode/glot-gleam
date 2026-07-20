import gleam/option
import glot_backend/auth/model/user_list_filters.{type UserListFilters}
import glot_backend/system/effect/error/db_error
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/pagination_model.{type CursorPagination}
import youid/uuid.{type Uuid}

pub type Effect(next) {
  GetUserByEmail(
    email: email_address_model.EmailAddress,
    next: fn(option.Option(user_model.HydratedUser)) -> next,
  )
  GetUserById(
    id: Uuid,
    next: fn(option.Option(user_model.HydratedUser)) -> next,
  )
  ListUsers(
    pagination: CursorPagination,
    filters: UserListFilters,
    next: fn(List(user_model.HydratedUser)) -> next,
  )
  CreateUser(
    user: user_model.User,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  UpdateUser(
    user: user_model.User,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeleteUsersByAccountId(
    account_id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
}

pub type EffectName {
  GetUserByEmailEffectName
  GetUserByIdEffectName
  ListUsersEffectName
  CreateUserEffectName
  UpdateUserEffectName
  DeleteUsersByAccountIdEffectName
}

pub fn map(effect: Effect(a), f: fn(a) -> b) -> Effect(b) {
  case effect {
    GetUserByEmail(email:, next:) ->
      GetUserByEmail(email: email, next: fn(value) { f(next(value)) })
    GetUserById(id:, next:) ->
      GetUserById(id: id, next: fn(value) { f(next(value)) })
    ListUsers(pagination:, filters:, next:) ->
      ListUsers(pagination: pagination, filters: filters, next: fn(value) {
        f(next(value))
      })
    CreateUser(user: user, next: next) ->
      CreateUser(user: user, next: fn(value) { f(next(value)) })
    UpdateUser(user: user, next: next) ->
      UpdateUser(user: user, next: fn(value) { f(next(value)) })
    DeleteUsersByAccountId(account_id: account_id, next: next) ->
      DeleteUsersByAccountId(account_id: account_id, next: fn(value) {
        f(next(value))
      })
  }
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetUserByEmailEffectName -> "get_user_by_email"
    GetUserByIdEffectName -> "get_user_by_id"
    ListUsersEffectName -> "list_users"
    CreateUserEffectName -> "create_user"
    UpdateUserEffectName -> "update_user"
    DeleteUsersByAccountIdEffectName -> "delete_users_by_account_id"
  }
}
