import gleam/option
import glot_core/auth/passkey_dto
import glot_frontend/api/response as api_response
import glot_frontend/app/event as app_event
import glot_frontend/public/login/command
import glot_frontend/public/login/message.{
  BeganPasskeyLogin, CompletedPasskeyLogin, FinishedPasskeyLogin,
  PasskeyLoginSubmitted,
}
import glot_frontend/public/login/model.{
  type Model, FinishingPasskey, PasskeyError, StartingPasskey, WaitingForPasskey,
}
import glot_frontend/public/login/success
import glot_frontend/ui/passkey

pub fn update(model: Model, msg: message.Msg) {
  case msg {
    PasskeyLoginSubmitted -> #(
      model.Model(
        ..model,
        passkey_challenge_id: option.None,
        passkey_status: StartingPasskey,
      ),
      command.BeginPasskeyLogin(BeganPasskeyLogin),
      app_event.NoAppEvent,
    )
    BeganPasskeyLogin(result) -> began(model, result)
    CompletedPasskeyLogin(result) -> completed(model, result)
    FinishedPasskeyLogin(result) -> finished(model, result)
    _ -> #(model, command.none(), app_event.NoAppEvent)
  }
}

fn began(
  model: Model,
  result: api_response.Response(passkey_dto.BeginPasskeyLoginResponse),
) {
  case result {
    api_response.Success(response) -> #(
      model.Model(
        ..model,
        passkey_challenge_id: option.Some(response.challenge_id),
        passkey_status: WaitingForPasskey,
      ),
      command.AuthenticatePasskey(response, CompletedPasskeyLogin),
      app_event.NoAppEvent,
    )
    api_response.ApiFailure(error) ->
      failure(model, api_response.error_message(error))
    api_response.HttpFailure(_) ->
      failure(model, "Could not start passkey login.")
  }
}

fn completed(
  model: Model,
  result: Result(passkey.AuthenticationResult, passkey.PasskeyError),
) {
  case result, model.passkey_challenge_id {
    Ok(authentication), option.Some(challenge_id) -> #(
      model.Model(..model, passkey_status: FinishingPasskey),
      command.FinishPasskeyLogin(
        passkey_dto.FinishPasskeyLoginRequest(
          challenge_id:,
          credential_id: authentication.credential_id,
          authenticator_data: authentication.authenticator_data,
          signature: authentication.signature,
          client_data_json: authentication.client_data_json,
        ),
        FinishedPasskeyLogin,
      ),
      app_event.NoAppEvent,
    )
    Ok(_), option.None -> failure(model, "Could not complete passkey login.")
    Error(error), _ -> failure(model, passkey.error_message(error))
  }
}

fn finished(model: Model, result: api_response.Response(Nil)) {
  case result {
    api_response.Success(_) -> success.login_succeeded(model)
    api_response.ApiFailure(error) ->
      failure(model, api_response.error_message(error))
    api_response.HttpFailure(_) ->
      failure(model, "Could not complete passkey login.")
  }
}

fn failure(model: Model, message: String) {
  #(
    model.Model(..model, passkey_status: PasskeyError(message)),
    command.none(),
    app_event.NoAppEvent,
  )
}
