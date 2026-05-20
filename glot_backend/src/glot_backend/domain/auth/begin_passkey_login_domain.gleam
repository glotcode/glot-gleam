import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/domain/auth/passkey_shared_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/error/auth_error
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

pub fn begin_passkey_login(
  ctx: context.Context,
  request: passkey_dto.BeginPasskeyLoginRequest,
) -> program_types.Program(passkey_dto.BeginPasskeyLoginResponse) {
  use maybe_user <- program.and_then(auth_effect.get_user_by_email(request.email))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(public_action.BeginPasskeyLoginAction),
    actor: api_action_policy_domain.actor_from_user(maybe_user),
  ))
  use user <- program.and_then(program.from_option(
    maybe_user,
    error.auth(auth_error.InvalidPasskeyAssertion),
  ))
  use credentials <- program.and_then(
    auth_effect.list_passkey_credentials_by_user_id(user.identity.id),
  )
  use _ <- program.and_then(case credentials {
    [] -> program.fail(error.auth(auth_error.InvalidPasskeyAssertion))
    _ -> program.succeed(Nil)
  })
  use challenge_id <- program.and_then(basic_effect.uuid_v7())
  let passkey_config = ctx.config.passkey
  use challenge_result <- program.and_then(webauthn_effect.new_authentication_challenge(
    passkey_config.origin,
    passkey_config.rp_id,
    "required",
    passkey_shared_domain.credential_entries(credentials),
  ))
  use challenge_result <- program.and_then(
    challenge_result
    |> result.map_error(error_from_webauthn)
    |> program.from_result,
  )
  let #(challenge, allow_credential_ids, challenge_state) = challenge_result
  let challenge_record =
    passkey_challenge_model.PasskeyChallenge(
      id: challenge_id,
      user_id: option.Some(user.identity.id),
      flow: passkey_challenge_model.PasskeyAuthenticationChallenge,
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

  program.succeed(passkey_dto.BeginPasskeyLoginResponse(
    challenge_id: challenge_id,
    challenge: challenge,
    rp_id: passkey_config.rp_id,
    allow_credential_ids: allow_credential_ids,
    timeout_seconds: passkey_config.challenge_timeout_seconds,
    user_verification: "required",
  ))
}

pub fn request_from_dynamic(
  ctx: context.Context,
  data: dynamic.Dynamic,
) -> program_types.Program(passkey_dto.BeginPasskeyLoginRequest) {
  program.decode_dynamic(
    data,
    passkey_dto.begin_login_request_decoder(
      email_address_model.decoder(ctx.regexes.is_email),
    ),
  )
}

fn error_from_webauthn(message: String) -> error.Error {
  error.infra(infra_error.RunRequestClientError(message))
}
