import gleam/list
import gleam/option
import gleam/result
import glot_backend/base64url
import glot_backend/context
import glot_backend/domain/auth/passkey_shared_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/error/infra_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/effect/webauthn/webauthn_effect
import glot_core/api_action
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_dto
import glot_core/email/email_address_model
import glot_core/public_action
import youid/uuid

const cose_alg_es256 = -7
const cose_alg_rs256 = -257

pub fn begin_passkey_registration(
  ctx: context.Context,
) -> program_types.Program(passkey_dto.BeginPasskeyRegistrationResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(public_action.BeginPasskeyRegistrationAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use existing_credentials <- program.and_then(
    auth_effect.list_passkey_credentials_by_user_id(session.user.identity.id),
  )
  use challenge_id <- program.and_then(basic_effect.uuid_v7())
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let passkey_config = dynamic_config.passkey_config(config)
  use challenge_result <- program.and_then(webauthn_effect.new_registration_challenge(
    passkey_config.origin,
    passkey_config.rp_id,
    "required",
  ))
  use challenge_result <- program.and_then(
    challenge_result
    |> result.map_error(error_from_webauthn)
    |> program.from_result,
  )
  let #(challenge, challenge_state) = challenge_result
  let challenge_record =
    passkey_challenge_model.PasskeyChallenge(
      id: challenge_id,
      user_id: option.Some(session.user.identity.id),
      flow: passkey_challenge_model.PasskeyRegistrationChallenge,
      challenge_state: challenge_state,
      created_at: ctx.timestamp,
      expires_at: passkey_shared_domain.add_seconds(
        ctx.timestamp,
        passkey_config.challenge_timeout_seconds,
      ),
    )
  use _ <- program.and_then(
    transaction_effect.run_all([
      auth_effect.create_passkey_challenge_tx(challenge_record),
      user_action_effect.create_user_action_tx(user_action),
    ]),
  )

  program.succeed(passkey_dto.BeginPasskeyRegistrationResponse(
    challenge_id: challenge_id,
    challenge: challenge,
    rp_id: passkey_config.rp_id,
    user_id: base64url.encode(uuid.to_bit_array(session.user.identity.id)),
    user_name: email_address_model.to_string(session.user.identity.email),
    user_display_name: session.user.identity.username,
    timeout_seconds: passkey_config.challenge_timeout_seconds,
    user_verification: "required",
    exclude_credential_ids: list.map(existing_credentials, fn(credential) {
      base64url.encode(credential.credential_id)
    }),
    algorithm_ids: [cose_alg_es256, cose_alg_rs256],
    attestation: "none",
  ))
}

fn error_from_webauthn(message: String) -> error.Error {
  error.infra(infra_error.RunRequestClientError(message))
}
