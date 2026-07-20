import gleam/result
import gleam/string
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error
import glot_core/auth/user_model.{type User}
import glot_core/email/email_address_model
import youid/uuid.{type Uuid}

pub fn create(
  db: db_helpers.Db,
  user: User,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.insert_user(
      id: uuid.to_bit_array(user.id),
      account_id: uuid.to_bit_array(user.account_id),
      email: email_address_model.to_string(user.email),
      username: user.username,
      role: user_model.role_to_string(user.role),
      last_login_at: user.last_login_at,
      created_at: user.created_at,
      updated_at: user.updated_at,
    ),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update(
  db: db_helpers.Db,
  user: User,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.update_user(
      account_id: uuid.to_bit_array(user.account_id),
      email: email_address_model.to_string(user.email),
      username: user.username,
      role: user_model.role_to_string(user.role),
      last_login_at: user.last_login_at,
      created_at: user.created_at,
      updated_at: user.updated_at,
      id: uuid.to_bit_array(user.id),
    ),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_by_account_id(
  db: db_helpers.Db,
  account_id: Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.delete_users_by_account_id(uuid.to_bit_array(account_id)),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

fn command_error(error) -> db_error.DbCommandError {
  db_error.DbCommandError(string.inspect(error))
}
