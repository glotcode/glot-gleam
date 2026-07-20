import gleam/option
import gleam/result
import gleam/string
import glot_backend/auth/ports/account_store
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error
import glot_core/auth/account_model
import youid/uuid

pub fn new(db: db_helpers.Db) -> account_store.AccountStore {
  account_store.AccountStore(
    create: fn(account) { create(db, account) },
    update: fn(account) { update(db, account) },
    delete: fn(id) { delete(db, id) },
  )
}

fn create(
  db: db_helpers.Db,
  account: account_model.Account,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_account(
      id: uuid.to_bit_array(account.id),
      account_state: account_model.account_state_to_string(
        account.account_state,
      ),
      account_state_reason: account.account_state_reason,
      account_tier: account_model.account_tier_to_string(account.account_tier),
      delete_job_id: account.delete_job_id |> option.map(uuid.to_bit_array),
      created_at: account.created_at,
      updated_at: account.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn update(
  db: db_helpers.Db,
  account: account_model.Account,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_account(
      id: uuid.to_bit_array(account.id),
      account_state: account_model.account_state_to_string(
        account.account_state,
      ),
      account_state_reason: account.account_state_reason,
      account_tier: account_model.account_tier_to_string(account.account_tier),
      delete_job_id: account.delete_job_id |> option.map(uuid.to_bit_array),
      created_at: account.created_at,
      updated_at: account.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn delete(
  db: db_helpers.Db,
  account_id: uuid.Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_account(uuid.to_bit_array(account_id)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}
