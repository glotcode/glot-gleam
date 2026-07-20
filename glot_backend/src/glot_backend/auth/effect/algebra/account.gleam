import glot_backend/system/effect/error/db_error
import glot_core/auth/account_model
import youid/uuid.{type Uuid}

pub type Effect(next) {
  CreateAccount(
    account: account_model.Account,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  UpdateAccount(
    account: account_model.Account,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeleteAccount(
    account_id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
}

pub type EffectName {
  CreateAccountEffectName
  UpdateAccountEffectName
  DeleteAccountEffectName
}

pub fn map(effect: Effect(a), f: fn(a) -> b) -> Effect(b) {
  case effect {
    CreateAccount(account: account, next: next) ->
      CreateAccount(account: account, next: fn(value) { f(next(value)) })
    UpdateAccount(account: account, next: next) ->
      UpdateAccount(account: account, next: fn(value) { f(next(value)) })
    DeleteAccount(account_id: account_id, next: next) ->
      DeleteAccount(account_id: account_id, next: fn(value) { f(next(value)) })
  }
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    CreateAccountEffectName -> "create_account"
    UpdateAccountEffectName -> "update_account"
    DeleteAccountEffectName -> "delete_account"
  }
}
