import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp
import glot_backend/base64url
import glot_backend/effect/error
import glot_backend/effect/error/auth_error
import glot_backend/effect/error/infra_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_credential_model
import glot_core/validation_error
import youid/uuid

pub fn add_seconds(
  ts: timestamp.Timestamp,
  seconds_to_add: Int,
) -> timestamp.Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(seconds + seconds_to_add, nanos)
}

pub fn require_not_expired(
  challenge: passkey_challenge_model.PasskeyChallenge,
  now: timestamp.Timestamp,
) -> program_types.Program(passkey_challenge_model.PasskeyChallenge) {
  case timestamp_is_on_or_before(now, challenge.expires_at) {
    True -> program.succeed(challenge)
    False -> program.fail(error.auth(auth_error.PasskeyChallengeExpired))
  }
}

pub fn require_flow(
  challenge: passkey_challenge_model.PasskeyChallenge,
  expected_flow: passkey_challenge_model.PasskeyChallengeFlow,
) -> program_types.Program(passkey_challenge_model.PasskeyChallenge) {
  case challenge.flow == expected_flow {
    True -> program.succeed(challenge)
    False -> program.fail(error.auth(auth_error.InvalidPasskeyAssertion))
  }
}

pub fn require_challenge_user(
  challenge: passkey_challenge_model.PasskeyChallenge,
  user_id: uuid.Uuid,
) -> program_types.Program(passkey_challenge_model.PasskeyChallenge) {
  case challenge.user_id {
    option.Some(challenge_user_id) if challenge_user_id == user_id ->
      program.succeed(challenge)
    _ -> program.fail(error.auth(auth_error.InvalidPasskeyAssertion))
  }
}

pub fn decode_base64url(
  field: String,
  value: String,
) -> program_types.Program(BitArray) {
  case string.trim(value) == "" {
    True ->
      program.fail(error.validation(validation_error.EmptyField(field)))
    False ->
      base64url.decode(value)
      |> result.map_error(fn(message) {
        error.infra(infra_error.RunRequestClientError(
          "Invalid base64url value for " <> field <> ": " <> message,
        ))
      })
      |> program.from_result
  }
}

pub fn challenge_state(
  challenge: passkey_challenge_model.PasskeyChallenge,
) -> BitArray {
  challenge.challenge_state
}

pub fn credential_entries(
  credentials: List(passkey_credential_model.PasskeyCredential),
) -> List(#(BitArray, BitArray)) {
  list.map(credentials, fn(credential) {
    #(credential.credential_id, credential.cose_key)
  })
}

fn timestamp_is_on_or_before(
  left: timestamp.Timestamp,
  right: timestamp.Timestamp,
) -> Bool {
  let #(left_seconds, left_nanos) =
    timestamp.to_unix_seconds_and_nanoseconds(left)
  let #(right_seconds, right_nanos) =
    timestamp.to_unix_seconds_and_nanoseconds(right)

  left_seconds < right_seconds
  || { left_seconds == right_seconds && left_nanos <= right_nanos }
}
