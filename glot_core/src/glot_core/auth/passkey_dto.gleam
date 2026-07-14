import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/time/timestamp
import glot_core/auth/platform_model
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import youid/uuid

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

pub type AccountPasskeyResponse {
  AccountPasskeyResponse(
    id: uuid.Uuid,
    os_name: option.Option(platform_model.OperatingSystem),
    browser_name: option.Option(platform_model.Browser),
    created_at: timestamp.Timestamp,
    last_used_at: option.Option(timestamp.Timestamp),
  )
}

pub type ListAccountPasskeysResponse {
  ListAccountPasskeysResponse(passkeys: List(AccountPasskeyResponse))
}

pub type DeleteAccountPasskeyRequest {
  DeleteAccountPasskeyRequest(id: uuid.Uuid)
}

pub fn delete_account_passkey_request_decoder() -> decode.Decoder(
  DeleteAccountPasskeyRequest,
) {
  use id <- decode.field("id", uuid_helpers.decoder())
  decode.success(DeleteAccountPasskeyRequest(id: id))
}

pub fn encode_delete_account_passkey_request(
  request: DeleteAccountPasskeyRequest,
) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(request.id))),
  ])
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

pub fn encode_finish_registration_request(
  request: FinishPasskeyRegistrationRequest,
) -> json.Json {
  json.object([
    #("challengeId", json.string(uuid.to_string(request.challenge_id))),
    #("attestationObject", json.string(request.attestation_object)),
    #("clientDataJson", json.string(request.client_data_json)),
  ])
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

pub fn encode_finish_login_request(
  request: FinishPasskeyLoginRequest,
) -> json.Json {
  json.object([
    #("challengeId", json.string(uuid.to_string(request.challenge_id))),
    #("credentialId", json.string(request.credential_id)),
    #("authenticatorData", json.string(request.authenticator_data)),
    #("signature", json.string(request.signature)),
    #("clientDataJson", json.string(request.client_data_json)),
  ])
}

pub fn begin_registration_response_decoder() -> decode.Decoder(
  BeginPasskeyRegistrationResponse,
) {
  use challenge_id <- decode.field("challengeId", uuid_helpers.decoder())
  use challenge <- decode.field("challenge", decode.string)
  use rp_id <- decode.field("rpId", decode.string)
  use user_id <- decode.field("userId", decode.string)
  use user_name <- decode.field("userName", decode.string)
  use user_display_name <- decode.field("userDisplayName", decode.string)
  use timeout_seconds <- decode.field("timeoutSeconds", decode.int)
  use user_verification <- decode.field("userVerification", decode.string)
  use exclude_credential_ids <- decode.field(
    "excludeCredentialIds",
    decode.list(decode.string),
  )
  use algorithm_ids <- decode.field("algorithmIds", decode.list(decode.int))
  use attestation <- decode.field("attestation", decode.string)

  decode.success(BeginPasskeyRegistrationResponse(
    challenge_id:,
    challenge:,
    rp_id:,
    user_id:,
    user_name:,
    user_display_name:,
    timeout_seconds:,
    user_verification:,
    exclude_credential_ids:,
    algorithm_ids:,
    attestation:,
  ))
}

pub fn begin_login_response_decoder() -> decode.Decoder(
  BeginPasskeyLoginResponse,
) {
  use challenge_id <- decode.field("challengeId", uuid_helpers.decoder())
  use challenge <- decode.field("challenge", decode.string)
  use rp_id <- decode.field("rpId", decode.string)
  use allow_credential_ids <- decode.field(
    "allowCredentialIds",
    decode.list(decode.string),
  )
  use timeout_seconds <- decode.field("timeoutSeconds", decode.int)
  use user_verification <- decode.field("userVerification", decode.string)

  decode.success(BeginPasskeyLoginResponse(
    challenge_id:,
    challenge:,
    rp_id:,
    allow_credential_ids:,
    timeout_seconds:,
    user_verification:,
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

pub fn encode_account_passkey(response: AccountPasskeyResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(response.id))),
    #(
      "osName",
      json.nullable(response.os_name, platform_model.encode_operating_system),
    ),
    #(
      "browserName",
      json.nullable(response.browser_name, platform_model.encode_browser),
    ),
    #("createdAt", timestamp_helpers.encode(response.created_at)),
    #(
      "lastUsedAt",
      json.nullable(response.last_used_at, timestamp_helpers.encode),
    ),
  ])
}

pub fn account_passkey_decoder() -> decode.Decoder(AccountPasskeyResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use os_name <- decode.field(
    "osName",
    decode.optional(platform_model.operating_system_decoder()),
  )
  use browser_name <- decode.field(
    "browserName",
    decode.optional(platform_model.browser_decoder()),
  )
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use last_used_at <- decode.field(
    "lastUsedAt",
    decode.optional(timestamp_helpers.decoder()),
  )
  decode.success(AccountPasskeyResponse(
    id:,
    os_name:,
    browser_name:,
    created_at:,
    last_used_at:,
  ))
}

pub fn encode_list_account_passkeys_response(
  response: ListAccountPasskeysResponse,
) -> json.Json {
  json.object([
    #("passkeys", json.array(response.passkeys, encode_account_passkey)),
  ])
}

pub fn list_account_passkeys_response_decoder() -> decode.Decoder(
  ListAccountPasskeysResponse,
) {
  use passkeys <- decode.field(
    "passkeys",
    decode.list(account_passkey_decoder()),
  )
  decode.success(ListAccountPasskeysResponse(passkeys: passkeys))
}
