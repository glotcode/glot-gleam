import glot_core/auth/passkey_dto
import glot_frontend/account/command
import glot_frontend/account/message.{
  type Msg, AccountPasskeysLoaded, BeganPasskeyRegistration,
  BeginPasskeySubmitted, DeletePasskeySubmitted, DeletedPasskey,
  FinishedPasskeyRegistration, PasskeyRegistrationCreated,
  PasskeysLoadingDelayElapsed,
}
import glot_frontend/account/model.{
  type Model, CreatingPasskey, DeletingPasskey, IdlePasskeys, LoadingPasskeys,
  Model, PasskeySaved, PasskeySetupError, PasskeysError, SavingPasskey,
  StartingPasskeySetup,
}
import glot_frontend/api/response as api_response
import glot_frontend/app/event as app_event
import glot_frontend/ui/delayed_loading
import glot_frontend/ui/passkey

pub fn update(
  model: Model,
  msg: Msg,
) -> #(Model, command.Command(Msg), app_event.AppEvent) {
  case msg {
    AccountPasskeysLoaded(result) ->
      case result {
        api_response.Success(response) -> #(
          Model(
            ..model,
            passkeys: response.passkeys,
            passkeys_status: IdlePasskeys,
            passkeys_loading_indicator: delayed_loading.finish(
              model.passkeys_loading_indicator,
            ),
          ),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.ApiFailure(error) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError(api_response.error_message(error)),
            passkeys_loading_indicator: delayed_loading.finish(
              model.passkeys_loading_indicator,
            ),
          ),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError("Could not load passkeys."),
            passkeys_loading_indicator: delayed_loading.finish(
              model.passkeys_loading_indicator,
            ),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    PasskeysLoadingDelayElapsed(generation) -> #(
      Model(
        ..model,
        passkeys_loading_indicator: delayed_loading.reveal(
          model.passkeys_loading_indicator,
          generation,
        ),
      ),
      command.none(),
      app_event.NoAppEvent,
    )

    BeginPasskeySubmitted -> #(
      Model(..model, passkey_setup_status: StartingPasskeySetup),
      command.BeginPasskeyRegistration(BeganPasskeyRegistration),
      app_event.NoAppEvent,
    )

    BeganPasskeyRegistration(result) ->
      case result {
        api_response.Success(response) -> #(
          Model(..model, passkey_setup_status: CreatingPasskey),
          command.CreatePasskey(response, fn(registration_result) {
            PasskeyRegistrationCreated(
              response.challenge_id,
              registration_result,
            )
          }),
          app_event.NoAppEvent,
        )

        api_response.ApiFailure(error) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(api_response.error_message(
              error,
            )),
          ),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(
              "Could not start passkey setup.",
            ),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    PasskeyRegistrationCreated(challenge_id, registration_result) ->
      case registration_result {
        Ok(registration) -> {
          let request =
            passkey_dto.FinishPasskeyRegistrationRequest(
              challenge_id: challenge_id,
              attestation_object: registration.attestation_object,
              client_data_json: registration.client_data_json,
            )
          #(
            Model(..model, passkey_setup_status: SavingPasskey),
            command.FinishPasskeyRegistration(
              request,
              FinishedPasskeyRegistration,
            ),
            app_event.NoAppEvent,
          )
        }

        Error(error) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(passkey.error_message(error)),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    FinishedPasskeyRegistration(result) ->
      case result {
        api_response.Success(_) -> {
          let #(passkeys_loading_indicator, generation) =
            delayed_loading.begin(model.passkeys_loading_indicator)
          #(
            Model(
              ..model,
              passkey_setup_status: PasskeySaved,
              passkeys_status: LoadingPasskeys,
              passkeys_loading_indicator:,
            ),
            command.batch([
              command.ListPasskeys(AccountPasskeysLoaded),
              command.Schedule(
                delayed_loading.delay(),
                PasskeysLoadingDelayElapsed(generation),
              ),
            ]),
            app_event.NoAppEvent,
          )
        }

        api_response.ApiFailure(error) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(api_response.error_message(
              error,
            )),
          ),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(
              "Could not save the new passkey.",
            ),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    DeletePasskeySubmitted(id) -> {
      let request = passkey_dto.DeleteAccountPasskeyRequest(id:)
      #(
        Model(..model, passkeys_status: DeletingPasskey(id)),
        command.DeletePasskey(request, fn(result) { DeletedPasskey(id, result) }),
        app_event.NoAppEvent,
      )
    }

    DeletedPasskey(_id, result) ->
      case result {
        api_response.Success(_) -> {
          let #(passkeys_loading_indicator, generation) =
            delayed_loading.begin(model.passkeys_loading_indicator)
          #(
            Model(
              ..model,
              passkeys_status: LoadingPasskeys,
              passkeys_loading_indicator:,
            ),
            command.batch([
              command.ListPasskeys(AccountPasskeysLoaded),
              command.Schedule(
                delayed_loading.delay(),
                PasskeysLoadingDelayElapsed(generation),
              ),
            ]),
            app_event.NoAppEvent,
          )
        }

        api_response.ApiFailure(error) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError(api_response.error_message(error)),
          ),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError("Could not delete passkey."),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    _ -> #(model, command.none(), app_event.NoAppEvent)
  }
}
