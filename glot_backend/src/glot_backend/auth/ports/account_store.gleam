import glot_backend/system/effect/error/db_error
import glot_core/auth/account_model
import youid/uuid.{type Uuid}

pub type AccountStore {
  AccountStore(
    create: fn(account_model.Account) -> Result(Nil, db_error.DbCommandError),
    update: fn(account_model.Account) -> Result(Nil, db_error.DbCommandError),
    delete: fn(Uuid) -> Result(Nil, db_error.DbCommandError),
  )
}
