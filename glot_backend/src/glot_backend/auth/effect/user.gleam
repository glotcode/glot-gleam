import gleam/option
import glot_backend/auth/effect/algebra/user as user_algebra
import glot_backend/auth/effect/command_result
import glot_backend/auth/effect/effect as auth_effect
import glot_backend/auth/model/user_list_filters.{type UserListFilters}
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/program_types
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/pagination_model.{type CursorPagination}
import youid/uuid.{type Uuid}

pub fn get_user_by_email(
  email email: email_address_model.EmailAddress,
) -> program_types.Program(option.Option(user_model.HydratedUser)) {
  program_types.Impure(
    program_types.DbEffect(get_user_by_email_effect(email, program_types.Pure)),
  )
}

pub fn get_user_by_id(
  id id: Uuid,
) -> program_types.Program(option.Option(user_model.HydratedUser)) {
  program_types.Impure(
    program_types.DbEffect(get_user_by_id_effect(id, program_types.Pure)),
  )
}

pub fn list_users(
  pagination pagination: CursorPagination,
  filters filters: UserListFilters,
) -> program_types.Program(List(user_model.HydratedUser)) {
  program_types.Impure(
    program_types.DbEffect(list_users_effect(
      pagination,
      filters,
      program_types.Pure,
    )),
  )
}

pub fn create_user(user user: user_model.User) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_user_effect(user, command_result.to_program)),
  )
}

pub fn update_user(user user: user_model.User) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(update_user_effect(user, command_result.to_program)),
  )
}

pub fn delete_users_by_account_id(id id: Uuid) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_users_by_account_id_effect(
      id,
      command_result.to_program,
    )),
  )
}

pub fn get_user_by_email_tx(
  email email: email_address_model.EmailAddress,
) -> program_types.TransactionProgram(option.Option(user_model.HydratedUser)) {
  program_types.TxImpure(get_user_by_email_effect(email, program_types.TxPure))
}

pub fn get_user_by_id_tx(
  id id: Uuid,
) -> program_types.TransactionProgram(option.Option(user_model.HydratedUser)) {
  program_types.TxImpure(get_user_by_id_effect(id, program_types.TxPure))
}

pub fn list_users_tx(
  pagination pagination: CursorPagination,
  filters filters: UserListFilters,
) -> program_types.TransactionProgram(List(user_model.HydratedUser)) {
  program_types.TxImpure(list_users_effect(
    pagination,
    filters,
    program_types.TxPure,
  ))
}

pub fn create_user_tx(
  user user: user_model.User,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_user_effect(
    user,
    command_result.to_transaction_program,
  ))
}

pub fn update_user_tx(
  user user: user_model.User,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(update_user_effect(
    user,
    command_result.to_transaction_program,
  ))
}

pub fn delete_users_by_account_id_tx(
  id id: Uuid,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_users_by_account_id_effect(
    id,
    command_result.to_transaction_program,
  ))
}

fn get_user_by_email_effect(
  email: email_address_model.EmailAddress,
  next: fn(option.Option(user_model.HydratedUser)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.user(user_algebra.GetUserByEmail(email:, next: next))
}

fn get_user_by_id_effect(
  id: Uuid,
  next: fn(option.Option(user_model.HydratedUser)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.user(user_algebra.GetUserById(id:, next: next))
}

fn list_users_effect(
  pagination: CursorPagination,
  filters: UserListFilters,
  next: fn(List(user_model.HydratedUser)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.user(user_algebra.ListUsers(
    pagination: pagination,
    filters: filters,
    next: next,
  ))
}

fn create_user_effect(
  user: user_model.User,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.user(user_algebra.CreateUser(user: user, next: next))
}

fn update_user_effect(
  user: user_model.User,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.user(user_algebra.UpdateUser(user: user, next: next))
}

fn delete_users_by_account_id_effect(
  id: Uuid,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.user(user_algebra.DeleteUsersByAccountId(
    account_id: id,
    next: next,
  ))
}
