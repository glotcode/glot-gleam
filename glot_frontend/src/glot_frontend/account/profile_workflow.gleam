import gleam/result
import gleam/string
import glot_core/auth/account_dto
import glot_core/auth/user_model
import glot_core/loadable
import glot_core/validation_error
import glot_frontend/account/command
import glot_frontend/account/message.{
  type Msg, AccountUpdated, UsernameChanged, UsernameSubmitted,
}
import glot_frontend/account/model.{
  type Model, Idle, Model, Saved, Saving, UsernameError,
}
import glot_frontend/api/response as api_response
import glot_frontend/app/event as app_event

pub fn update(
  model: Model,
  msg: Msg,
) -> #(Model, command.Command(Msg), app_event.AppEvent) {
  case msg {
    UsernameChanged(username) -> #(
      Model(..model, username: username, status: Idle),
      command.none(),
      app_event.NoAppEvent,
    )

    UsernameSubmitted -> {
      let username = string.trim(model.username)

      let validation =
        user_model.validate_username(username)
        |> result.map_error(validation_error.message)

      case validation {
        Ok(_) -> {
          let request = account_dto.UpdateAccountRequest(username:)
          #(
            Model(..model, username: username, status: Saving),
            command.UpdateAccount(request, AccountUpdated),
            app_event.NoAppEvent,
          )
        }

        _ -> #(
          Model(
            ..model,
            username: username,
            status: UsernameError(result.unwrap_error(
              validation,
              "Invalid username.",
            )),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }
    }

    AccountUpdated(result) ->
      case result {
        api_response.Success(account) -> {
          #(
            Model(
              ..model,
              account: loadable.Loaded(account),
              username: account.username,
              status: Saved,
            ),
            command.none(),
            app_event.RefreshSession,
          )
        }

        api_response.ApiFailure(error) -> #(
          Model(
            ..model,
            status: UsernameError(api_response.error_message(error)),
          ),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(..model, status: UsernameError("Could not update account.")),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    _ -> #(model, command.none(), app_event.NoAppEvent)
  }
}
