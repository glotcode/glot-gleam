import gleam/dynamic/decode
import gleam/json
import gleam/result
import glot_core/auth/passkey_dto
import lustre/effect.{type Effect}

pub type PasskeyErrorKind {
  UnsupportedPasskey
  CancelledPasskey
  FailedPasskey
}

pub type PasskeyError {
  PasskeyError(kind: PasskeyErrorKind, message: String)
}

pub type RegistrationResult {
  RegistrationResult(attestation_object: String, client_data_json: String)
}

pub type AuthenticationResult {
  AuthenticationResult(
    credential_id: String,
    authenticator_data: String,
    signature: String,
    client_data_json: String,
  )
}

pub fn begin_registration(
  options: passkey_dto.BeginPasskeyRegistrationResponse,
  to_msg: fn(Result(RegistrationResult, PasskeyError)) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    start_registration(
      options
        |> passkey_dto.encode_begin_registration_response()
        |> json.to_string(),
      fn(success_json) {
        dispatch(
          success_json
          |> parse_registration_result()
          |> result.map_error(fn(_) {
            PasskeyError(
              kind: FailedPasskey,
              message: "Could not process the passkey response.",
            )
          })
          |> to_msg,
        )
      },
      fn(error_json) {
        let error = case parse_passkey_error(error_json) {
          Ok(parsed_error) -> parsed_error
          Error(_) ->
            PasskeyError(kind: FailedPasskey, message: "Passkey setup failed.")
        }

        dispatch(error |> Error |> to_msg)
      },
    )
  })
}

pub fn begin_authentication(
  options: passkey_dto.BeginPasskeyLoginResponse,
  to_msg: fn(Result(AuthenticationResult, PasskeyError)) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    start_authentication(
      options
        |> passkey_dto.encode_begin_login_response()
        |> json.to_string(),
      fn(success_json) {
        dispatch(
          success_json
          |> parse_authentication_result()
          |> result.map_error(fn(_) {
            PasskeyError(
              kind: FailedPasskey,
              message: "Could not process the passkey response.",
            )
          })
          |> to_msg,
        )
      },
      fn(error_json) {
        let error = case parse_passkey_error(error_json) {
          Ok(parsed_error) -> parsed_error
          Error(_) ->
            PasskeyError(kind: FailedPasskey, message: "Passkey login failed.")
        }

        dispatch(error |> Error |> to_msg)
      },
    )
  })
}

pub fn error_message(error: PasskeyError) -> String {
  error.message
}

pub fn is_supported() -> Bool {
  supports_passkeys()
}

fn parse_registration_result(value: String) -> Result(RegistrationResult, Nil) {
  json.parse(value, registration_result_decoder())
  |> result.map_error(fn(_) { Nil })
}

fn parse_authentication_result(
  value: String,
) -> Result(AuthenticationResult, Nil) {
  json.parse(value, authentication_result_decoder())
  |> result.map_error(fn(_) { Nil })
}

fn parse_passkey_error(value: String) -> Result(PasskeyError, Nil) {
  json.parse(value, passkey_error_decoder()) |> result.map_error(fn(_) { Nil })
}

fn registration_result_decoder() -> decode.Decoder(RegistrationResult) {
  use attestation_object <- decode.field("attestationObject", decode.string)
  use client_data_json <- decode.field("clientDataJson", decode.string)

  decode.success(RegistrationResult(
    attestation_object: attestation_object,
    client_data_json: client_data_json,
  ))
}

fn authentication_result_decoder() -> decode.Decoder(AuthenticationResult) {
  use credential_id <- decode.field("credentialId", decode.string)
  use authenticator_data <- decode.field("authenticatorData", decode.string)
  use signature <- decode.field("signature", decode.string)
  use client_data_json <- decode.field("clientDataJson", decode.string)

  decode.success(AuthenticationResult(
    credential_id: credential_id,
    authenticator_data: authenticator_data,
    signature: signature,
    client_data_json: client_data_json,
  ))
}

fn passkey_error_decoder() -> decode.Decoder(PasskeyError) {
  use kind <- decode.field("kind", passkey_error_kind_decoder())
  use message <- decode.field("message", decode.string)
  decode.success(PasskeyError(kind:, message:))
}

fn passkey_error_kind_decoder() -> decode.Decoder(PasskeyErrorKind) {
  decode.then(decode.string, fn(value) {
    case value {
      "unsupported" -> decode.success(UnsupportedPasskey)
      "cancelled" -> decode.success(CancelledPasskey)
      "failed" -> decode.success(FailedPasskey)
      _ -> decode.failure(FailedPasskey, "PasskeyErrorKind")
    }
  })
}

@external(javascript, "./passkey_ffi.mjs", "startRegistration")
fn start_registration(
  options_json: String,
  on_success: fn(String) -> Nil,
  on_error: fn(String) -> Nil,
) -> Nil

@external(javascript, "./passkey_ffi.mjs", "startAuthentication")
fn start_authentication(
  options_json: String,
  on_success: fn(String) -> Nil,
  on_error: fn(String) -> Nil,
) -> Nil

@external(javascript, "./passkey_ffi.mjs", "supportsPasskeys")
fn supports_passkeys() -> Bool
