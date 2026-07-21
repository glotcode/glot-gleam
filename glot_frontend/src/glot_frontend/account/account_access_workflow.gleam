import glot_core/route
import glot_frontend/account/command
import glot_frontend/account/message.{
  type Msg, AccountLoaded, CancelDeleteSubmitted, DeleteCanceled,
  DeleteScheduled, LoggedOut, LogoutSubmitted, ScheduleDeleteSubmitted,
  ToggleDangerZone,
}
import glot_frontend/account/model.{
  type Model, CancelingDelete, DeleteError, Idle, LoggingOut, LogoutError, Model,
  SchedulingDelete,
}
import glot_frontend/api/response as api_response
import glot_frontend/app/event as app_event

pub fn update(
  model: Model,
  msg: Msg,
) -> #(Model, command.Command(Msg), app_event.AppEvent) {
  case msg {
    LogoutSubmitted -> #(
      Model(..model, status: LoggingOut),
      command.Logout(LoggedOut),
      app_event.NoAppEvent,
    )

    ScheduleDeleteSubmitted -> #(
      Model(..model, status: SchedulingDelete),
      command.ScheduleDelete(DeleteScheduled),
      app_event.NoAppEvent,
    )

    DeleteScheduled(result) ->
      case result {
        api_response.Success(_) -> #(
          Model(..model, status: Idle),
          command.GetAccount(AccountLoaded),
          app_event.NoAppEvent,
        )

        api_response.ApiFailure(error) -> #(
          Model(..model, status: DeleteError(api_response.error_message(error))),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(
            ..model,
            status: DeleteError("Could not schedule account deletion."),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    CancelDeleteSubmitted -> #(
      Model(..model, status: CancelingDelete),
      command.CancelDelete(DeleteCanceled),
      app_event.NoAppEvent,
    )

    DeleteCanceled(result) ->
      case result {
        api_response.Success(_) -> #(
          Model(..model, status: Idle),
          command.GetAccount(AccountLoaded),
          app_event.NoAppEvent,
        )

        api_response.ApiFailure(error) -> #(
          Model(..model, status: DeleteError(api_response.error_message(error))),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(
            ..model,
            status: DeleteError("Could not cancel account deletion."),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    ToggleDangerZone -> #(
      Model(..model, danger_zone_expanded: !model.danger_zone_expanded),
      command.none(),
      app_event.NoAppEvent,
    )

    LoggedOut(result) ->
      case result {
        api_response.Success(_) -> #(
          Model(..model, status: Idle),
          command.NavigateReplace(route.to_string(route.Public(route.Home))),
          app_event.RefreshSession,
        )

        api_response.ApiFailure(error) -> #(
          Model(..model, status: LogoutError(api_response.error_message(error))),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(..model, status: LogoutError("Could not log out.")),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    _ -> #(model, command.none(), app_event.NoAppEvent)
  }
}
