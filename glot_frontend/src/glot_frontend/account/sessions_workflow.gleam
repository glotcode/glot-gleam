import glot_core/auth/account_session_dto
import glot_frontend/account/command
import glot_frontend/account/message.{
  type Msg, AccountSessionsLoaded, DeleteSessionSubmitted, DeletedSession,
  SessionLoaded, SessionsLoadingDelayElapsed,
}
import glot_frontend/account/model.{
  type Model, DeletingSession, IdleSessions, LoadingSessions, Model,
  SessionsError,
}
import glot_frontend/api/response as api_response
import glot_frontend/app/event as app_event
import glot_frontend/ui/delayed_loading

pub fn update(
  model: Model,
  msg: Msg,
) -> #(Model, command.Command(Msg), app_event.AppEvent) {
  case msg {
    AccountSessionsLoaded(result) ->
      case result {
        api_response.Success(response) -> #(
          Model(
            ..model,
            sessions: response.sessions,
            sessions_status: IdleSessions,
            sessions_loading_indicator: delayed_loading.finish(
              model.sessions_loading_indicator,
            ),
          ),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.ApiFailure(error) -> #(
          Model(
            ..model,
            sessions_status: SessionsError(api_response.error_message(error)),
            sessions_loading_indicator: delayed_loading.finish(
              model.sessions_loading_indicator,
            ),
          ),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(
            ..model,
            sessions_status: SessionsError("Could not load sessions."),
            sessions_loading_indicator: delayed_loading.finish(
              model.sessions_loading_indicator,
            ),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    SessionsLoadingDelayElapsed(generation) -> #(
      Model(
        ..model,
        sessions_loading_indicator: delayed_loading.reveal(
          model.sessions_loading_indicator,
          generation,
        ),
      ),
      command.none(),
      app_event.NoAppEvent,
    )

    DeleteSessionSubmitted(id) -> {
      let request = account_session_dto.DeleteAccountSessionRequest(id:)
      #(
        Model(..model, sessions_status: DeletingSession(id)),
        command.DeleteSession(request, fn(result) { DeletedSession(id, result) }),
        app_event.NoAppEvent,
      )
    }

    DeletedSession(_id, result) ->
      case result {
        api_response.Success(_) -> {
          let #(sessions_loading_indicator, generation) =
            delayed_loading.begin(model.sessions_loading_indicator)
          #(
            Model(
              ..model,
              sessions_status: LoadingSessions,
              sessions_loading_indicator:,
            ),
            command.batch([
              command.GetSession(SessionLoaded),
              command.ListSessions(AccountSessionsLoaded),
              command.Schedule(
                delayed_loading.delay(),
                SessionsLoadingDelayElapsed(generation),
              ),
            ]),
            app_event.RefreshSession,
          )
        }

        api_response.ApiFailure(error) -> #(
          Model(
            ..model,
            sessions_status: SessionsError(api_response.error_message(error)),
          ),
          command.none(),
          app_event.NoAppEvent,
        )

        api_response.HttpFailure(_) -> #(
          Model(
            ..model,
            sessions_status: SessionsError("Could not delete session."),
          ),
          command.none(),
          app_event.NoAppEvent,
        )
      }

    _ -> #(model, command.none(), app_event.NoAppEvent)
  }
}
