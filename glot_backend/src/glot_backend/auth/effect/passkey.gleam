import gleam/option
import glot_backend/auth/effect/algebra/passkey as passkey_algebra
import glot_backend/auth/effect/command_result
import glot_backend/auth/effect/effect as auth_effect
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/program_types
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_credential_model
import youid/uuid.{type Uuid}

pub fn get_passkey_credential_by_credential_id(
  credential_id credential_id: BitArray,
) -> program_types.Program(
  option.Option(passkey_credential_model.PasskeyCredential),
) {
  program_types.Impure(
    program_types.DbEffect(get_passkey_credential_by_credential_id_effect(
      credential_id,
      program_types.Pure,
    )),
  )
}

pub fn list_passkey_credentials_by_user_id(
  user_id user_id: Uuid,
) -> program_types.Program(List(passkey_credential_model.PasskeyCredential)) {
  program_types.Impure(
    program_types.DbEffect(list_passkey_credentials_by_user_id_effect(
      user_id,
      program_types.Pure,
    )),
  )
}

pub fn get_passkey_challenge_by_id(
  id id: Uuid,
) -> program_types.Program(
  option.Option(passkey_challenge_model.PasskeyChallenge),
) {
  program_types.Impure(
    program_types.DbEffect(get_passkey_challenge_by_id_effect(
      id,
      program_types.Pure,
    )),
  )
}

pub fn create_passkey_credential(
  passkey_credential passkey_credential: passkey_credential_model.PasskeyCredential,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_passkey_credential_effect(
      passkey_credential,
      command_result.to_program,
    )),
  )
}

pub fn create_passkey_challenge(
  passkey_challenge passkey_challenge: passkey_challenge_model.PasskeyChallenge,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_passkey_challenge_effect(
      passkey_challenge,
      command_result.to_program,
    )),
  )
}

pub fn delete_passkey_credential(id id: Uuid) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_passkey_credential_effect(
      id,
      command_result.to_program,
    )),
  )
}

pub fn update_passkey_credential(
  passkey_credential passkey_credential: passkey_credential_model.PasskeyCredential,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(update_passkey_credential_effect(
      passkey_credential,
      command_result.to_program,
    )),
  )
}

pub fn delete_passkey_challenge(id id: Uuid) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_passkey_challenge_effect(
      id,
      command_result.to_program,
    )),
  )
}

pub fn get_passkey_credential_by_credential_id_tx(
  credential_id credential_id: BitArray,
) -> program_types.TransactionProgram(
  option.Option(passkey_credential_model.PasskeyCredential),
) {
  program_types.TxImpure(get_passkey_credential_by_credential_id_effect(
    credential_id,
    program_types.TxPure,
  ))
}

pub fn list_passkey_credentials_by_user_id_tx(
  user_id user_id: Uuid,
) -> program_types.TransactionProgram(
  List(passkey_credential_model.PasskeyCredential),
) {
  program_types.TxImpure(list_passkey_credentials_by_user_id_effect(
    user_id,
    program_types.TxPure,
  ))
}

pub fn get_passkey_challenge_by_id_tx(
  id id: Uuid,
) -> program_types.TransactionProgram(
  option.Option(passkey_challenge_model.PasskeyChallenge),
) {
  program_types.TxImpure(get_passkey_challenge_by_id_effect(
    id,
    program_types.TxPure,
  ))
}

pub fn create_passkey_credential_tx(
  passkey_credential passkey_credential: passkey_credential_model.PasskeyCredential,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_passkey_credential_effect(
    passkey_credential,
    command_result.to_transaction_program,
  ))
}

pub fn create_passkey_challenge_tx(
  passkey_challenge passkey_challenge: passkey_challenge_model.PasskeyChallenge,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_passkey_challenge_effect(
    passkey_challenge,
    command_result.to_transaction_program,
  ))
}

pub fn delete_passkey_credential_tx(
  id id: Uuid,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_passkey_credential_effect(
    id,
    command_result.to_transaction_program,
  ))
}

pub fn update_passkey_credential_tx(
  passkey_credential passkey_credential: passkey_credential_model.PasskeyCredential,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(update_passkey_credential_effect(
    passkey_credential,
    command_result.to_transaction_program,
  ))
}

pub fn delete_passkey_challenge_tx(
  id id: Uuid,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_passkey_challenge_effect(
    id,
    command_result.to_transaction_program,
  ))
}

fn get_passkey_credential_by_credential_id_effect(
  credential_id: BitArray,
  next: fn(option.Option(passkey_credential_model.PasskeyCredential)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.passkey(passkey_algebra.GetPasskeyCredentialByCredentialId(
    credential_id: credential_id,
    next: next,
  ))
}

fn delete_passkey_credential_effect(
  id: Uuid,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.passkey(passkey_algebra.DeletePasskeyCredential(
    id: id,
    next: next,
  ))
}

fn list_passkey_credentials_by_user_id_effect(
  user_id: Uuid,
  next: fn(List(passkey_credential_model.PasskeyCredential)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.passkey(passkey_algebra.ListPasskeyCredentialsByUserId(
    user_id: user_id,
    next: next,
  ))
}

fn get_passkey_challenge_by_id_effect(
  id: Uuid,
  next: fn(option.Option(passkey_challenge_model.PasskeyChallenge)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.passkey(passkey_algebra.GetPasskeyChallengeById(
    id: id,
    next: next,
  ))
}

fn create_passkey_credential_effect(
  passkey_credential: passkey_credential_model.PasskeyCredential,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.passkey(passkey_algebra.CreatePasskeyCredential(
    passkey_credential: passkey_credential,
    next: next,
  ))
}

fn create_passkey_challenge_effect(
  passkey_challenge: passkey_challenge_model.PasskeyChallenge,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.passkey(passkey_algebra.CreatePasskeyChallenge(
    passkey_challenge: passkey_challenge,
    next: next,
  ))
}

fn update_passkey_credential_effect(
  passkey_credential: passkey_credential_model.PasskeyCredential,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.passkey(passkey_algebra.UpdatePasskeyCredential(
    passkey_credential: passkey_credential,
    next: next,
  ))
}

fn delete_passkey_challenge_effect(
  id: Uuid,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  auth_effect.passkey(passkey_algebra.DeletePasskeyChallenge(id: id, next: next))
}
