import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/browser_info
import glot_backend/context
import glot_backend/domain/auth/passkey_shared_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/error/auth_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/effect/webauthn/webauthn_effect
import glot_core/api_action
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_credential_model
import glot_core/auth/passkey_dto
import glot_core/public_action

pub fn finish_passkey_registration(
  ctx: context.Context,
  request: passkey_dto.FinishPasskeyRegistrationRequest,
) -> program_types.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use maybe_user <- program.and_then(auth_effect.get_user_by_id(
    session.user.identity.id,
  ))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(public_action.FinishPasskeyRegistrationAction),
    actor: api_action_policy_domain.actor_from_user(maybe_user),
  ))
  use challenge <- program.and_then(
    auth_effect.get_passkey_challenge_by_id(request.challenge_id)
    |> program.and_then(program.from_option(
      _,
      error.auth(auth_error.PasskeyChallengeNotFound),
    )),
  )
  use challenge <- program.and_then(passkey_shared_domain.require_flow(
    challenge,
    passkey_challenge_model.PasskeyRegistrationChallenge,
  ))
  use challenge <- program.and_then(passkey_shared_domain.require_challenge_user(
    challenge,
    session.user.identity.id,
  ))
  use challenge <- program.and_then(passkey_shared_domain.require_not_expired(
    challenge,
    ctx.timestamp,
  ))
  use attestation_object <- program.and_then(passkey_shared_domain.decode_base64url(
    "attestationObject",
    request.attestation_object,
  ))
  use registration_result <- program.and_then(webauthn_effect.register(
    attestation_object,
    request.client_data_json,
    passkey_shared_domain.challenge_state(challenge),
  ))
  use registration_result <- program.and_then(
    registration_result
    |> result.map_error(fn(_) { error.auth(auth_error.InvalidPasskeyAssertion) })
    |> program.from_result,
  )
  let #(credential_id, cose_key, sign_count, aaguid) = registration_result
  use existing_credential <- program.and_then(
    auth_effect.get_passkey_credential_by_credential_id(credential_id),
  )
  use _ <- program.and_then(case existing_credential {
    option.None -> program.succeed(Nil)
    option.Some(_) -> program.fail(error.auth(auth_error.InvalidPasskeyAssertion))
  })
  use credential_record_id <- program.and_then(basic_effect.uuid_v7())
  let browser_info = browser_info.from_user_agent(ctx.client_info.user_agent)
  let credential =
    passkey_credential_model.PasskeyCredential(
      id: credential_record_id,
      user_id: session.user.identity.id,
      credential_id: credential_id,
      cose_key: cose_key,
      sign_count: sign_count,
      aaguid: aaguid,
      os_name: browser_info.os_name,
      browser_name: browser_info.browser_name,
      user_agent: browser_info.truncate_user_agent(
        ctx.client_info.user_agent,
      ),
      created_at: ctx.timestamp,
      updated_at: ctx.timestamp,
      last_used_at: option.None,
    )
  use _ <- program.and_then(
    transaction_effect.run_all([
      auth_effect.create_passkey_credential_tx(credential),
      auth_effect.delete_passkey_challenge_tx(challenge.id),
      user_action_effect.create_user_action_tx(user_action),
    ]),
  )

  program.succeed(Nil)
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(passkey_dto.FinishPasskeyRegistrationRequest) {
  program.decode_dynamic(data, passkey_dto.finish_registration_request_decoder())
}
