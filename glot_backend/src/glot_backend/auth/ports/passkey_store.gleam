import gleam/option
import glot_backend/system/effect/error/db_error
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_credential_model
import youid/uuid.{type Uuid}

pub type PasskeyStore {
  PasskeyStore(
    get_credential_by_credential_id: fn(BitArray) ->
      Result(
        option.Option(passkey_credential_model.PasskeyCredential),
        db_error.DbQueryError,
      ),
    list_credentials_by_user_id: fn(Uuid) ->
      Result(
        List(passkey_credential_model.PasskeyCredential),
        db_error.DbQueryError,
      ),
    get_challenge_by_id: fn(Uuid) ->
      Result(
        option.Option(passkey_challenge_model.PasskeyChallenge),
        db_error.DbQueryError,
      ),
    create_credential: fn(passkey_credential_model.PasskeyCredential) ->
      Result(Nil, db_error.DbCommandError),
    update_credential: fn(passkey_credential_model.PasskeyCredential) ->
      Result(Nil, db_error.DbCommandError),
    delete_credential: fn(Uuid) -> Result(Nil, db_error.DbCommandError),
    create_challenge: fn(passkey_challenge_model.PasskeyChallenge) ->
      Result(Nil, db_error.DbCommandError),
    delete_challenge: fn(Uuid) -> Result(Nil, db_error.DbCommandError),
  )
}
