import gleam/dynamic/decode
import gleam/json
import glot_core/email/email_address_model
import glot_core/helpers/uuid_helpers
import youid/uuid

pub type BeginPasskeyLoginRequest {
  BeginPasskeyLoginRequest(email: email_address_model.EmailAddress)
}

pub type BeginPasskeyRegistrationResponse {
  BeginPasskeyRegistrationResponse(
    challenge_id: uuid.Uuid,
    challenge: String,
    rp_id: String,
    user_id: String,
    user_name: String,
    user_display_name: String,
    timeout_seconds: Int,
    user_verification: String,
    exclude_credential_ids: List(String),
    algorithm_ids: List(Int),
    attestation: String,
  )
}

pub type BeginPasskeyLoginResponse {
  BeginPasskeyLoginResponse(
    challenge_id: uuid.Uuid,
    challenge: String,
    rp_id: String,
    allow_credential_ids: List(String),
    timeout_seconds: Int,
    user_verification: String,
  )
}

pub type FinishPasskeyRegistrationRequest {
  FinishPasskeyRegistrationRequest(
    challenge_id: uuid.Uuid,
    attestation_object: String,
    client_data_json: String,
  )
}

pub type FinishPasskeyLoginRequest {
  FinishPasskeyLoginRequest(
    challenge_id: uuid.Uuid,
    credential_id: String,
    authenticator_data: String,
    signature: String,
    client_data_json: String,
  )
}

pub fn begin_login_request_decoder(
  is_email: decode.Decoder(email_address_model.EmailAddress),
) -> decode.Decoder(BeginPasskeyLoginRequest) {
  use email <- decode.field("email", is_email)
  decode.success(BeginPasskeyLoginRequest(email: email))
}

pub fn finish_registration_request_decoder() -> decode.Decoder(
  FinishPasskeyRegistrationRequest,
) {
  use challenge_id <- decode.field("challengeId", uuid_helpers.decoder())
  use attestation_object <- decode.field("attestationObject", decode.string)
  use client_data_json <- decode.field("clientDataJson", decode.string)
  decode.success(FinishPasskeyRegistrationRequest(
    challenge_id: challenge_id,
    attestation_object: attestation_object,
    client_data_json: client_data_json,
  ))
}

pub fn finish_login_request_decoder() -> decode.Decoder(
  FinishPasskeyLoginRequest,
) {
  use challenge_id <- decode.field("challengeId", uuid_helpers.decoder())
  use credential_id <- decode.field("credentialId", decode.string)
  use authenticator_data <- decode.field("authenticatorData", decode.string)
  use signature <- decode.field("signature", decode.string)
  use client_data_json <- decode.field("clientDataJson", decode.string)
  decode.success(FinishPasskeyLoginRequest(
    challenge_id: challenge_id,
    credential_id: credential_id,
    authenticator_data: authenticator_data,
    signature: signature,
    client_data_json: client_data_json,
  ))
}

pub fn encode_begin_registration_response(
  response: BeginPasskeyRegistrationResponse,
) -> json.Json {
  json.object([
    #("challengeId", json.string(uuid.to_string(response.challenge_id))),
    #("challenge", json.string(response.challenge)),
    #("rpId", json.string(response.rp_id)),
    #("userId", json.string(response.user_id)),
    #("userName", json.string(response.user_name)),
    #("userDisplayName", json.string(response.user_display_name)),
    #("timeoutSeconds", json.int(response.timeout_seconds)),
    #("userVerification", json.string(response.user_verification)),
    #(
      "excludeCredentialIds",
      json.array(response.exclude_credential_ids, json.string),
    ),
    #("algorithmIds", json.array(response.algorithm_ids, json.int)),
    #("attestation", json.string(response.attestation)),
  ])
}

pub fn encode_begin_login_response(
  response: BeginPasskeyLoginResponse,
) -> json.Json {
  json.object([
    #("challengeId", json.string(uuid.to_string(response.challenge_id))),
    #("challenge", json.string(response.challenge)),
    #("rpId", json.string(response.rp_id)),
    #(
      "allowCredentialIds",
      json.array(response.allow_credential_ids, json.string),
    ),
    #("timeoutSeconds", json.int(response.timeout_seconds)),
    #("userVerification", json.string(response.user_verification)),
  ])
}
