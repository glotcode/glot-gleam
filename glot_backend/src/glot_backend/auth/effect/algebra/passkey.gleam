import gleam/option
import glot_backend/system/effect/error/db_error
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_credential_model
import youid/uuid.{type Uuid}

pub type Effect(next) {
  GetPasskeyCredentialByCredentialId(
    credential_id: BitArray,
    next: fn(option.Option(passkey_credential_model.PasskeyCredential)) -> next,
  )
  ListPasskeyCredentialsByUserId(
    user_id: Uuid,
    next: fn(List(passkey_credential_model.PasskeyCredential)) -> next,
  )
  GetPasskeyChallengeById(
    id: Uuid,
    next: fn(option.Option(passkey_challenge_model.PasskeyChallenge)) -> next,
  )
  CreatePasskeyCredential(
    passkey_credential: passkey_credential_model.PasskeyCredential,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  CreatePasskeyChallenge(
    passkey_challenge: passkey_challenge_model.PasskeyChallenge,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeletePasskeyCredential(
    id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  UpdatePasskeyCredential(
    passkey_credential: passkey_credential_model.PasskeyCredential,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeletePasskeyChallenge(
    id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
}

pub type EffectName {
  GetPasskeyCredentialByCredentialIdEffectName
  ListPasskeyCredentialsByUserIdEffectName
  GetPasskeyChallengeByIdEffectName
  CreatePasskeyCredentialEffectName
  CreatePasskeyChallengeEffectName
  DeletePasskeyCredentialEffectName
  UpdatePasskeyCredentialEffectName
  DeletePasskeyChallengeEffectName
}

pub fn map(effect: Effect(a), f: fn(a) -> b) -> Effect(b) {
  case effect {
    GetPasskeyCredentialByCredentialId(credential_id:, next:) ->
      GetPasskeyCredentialByCredentialId(
        credential_id: credential_id,
        next: fn(value) { f(next(value)) },
      )
    ListPasskeyCredentialsByUserId(user_id:, next:) ->
      ListPasskeyCredentialsByUserId(user_id: user_id, next: fn(value) {
        f(next(value))
      })
    GetPasskeyChallengeById(id:, next:) ->
      GetPasskeyChallengeById(id: id, next: fn(value) { f(next(value)) })
    CreatePasskeyCredential(passkey_credential: passkey_credential, next: next) ->
      CreatePasskeyCredential(
        passkey_credential: passkey_credential,
        next: fn(value) { f(next(value)) },
      )
    CreatePasskeyChallenge(passkey_challenge: passkey_challenge, next: next) ->
      CreatePasskeyChallenge(
        passkey_challenge: passkey_challenge,
        next: fn(value) { f(next(value)) },
      )
    DeletePasskeyCredential(id: id, next: next) ->
      DeletePasskeyCredential(id: id, next: fn(value) { f(next(value)) })
    UpdatePasskeyCredential(passkey_credential: passkey_credential, next: next) ->
      UpdatePasskeyCredential(
        passkey_credential: passkey_credential,
        next: fn(value) { f(next(value)) },
      )
    DeletePasskeyChallenge(id: id, next: next) ->
      DeletePasskeyChallenge(id: id, next: fn(value) { f(next(value)) })
  }
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetPasskeyCredentialByCredentialIdEffectName ->
      "get_passkey_credential_by_credential_id"
    ListPasskeyCredentialsByUserIdEffectName ->
      "list_passkey_credentials_by_user_id"
    GetPasskeyChallengeByIdEffectName -> "get_passkey_challenge_by_id"
    CreatePasskeyCredentialEffectName -> "create_passkey_credential"
    CreatePasskeyChallengeEffectName -> "create_passkey_challenge"
    DeletePasskeyCredentialEffectName -> "delete_passkey_credential"
    UpdatePasskeyCredentialEffectName -> "update_passkey_credential"
    DeletePasskeyChallengeEffectName -> "delete_passkey_challenge"
  }
}
