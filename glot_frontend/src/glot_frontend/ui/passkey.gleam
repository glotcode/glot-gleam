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

pub fn error_message(error: PasskeyError) -> String {
  error.message
}
