import gleam/option
import gleam/string
import glot_core/admin/run_log_dto
import glot_core/language
import glot_core/loadable
import glot_core/pagination_model
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/cursor_request
import glot_frontend/admin/run_logs/list_message.{
  ApplyFilters, LanguageFilterChanged, LogsLoaded, NextPageClicked,
  OutcomeFilterSelected, PreviousPageClicked, RequestIdFilterChanged,
  SessionIdFilterChanged, UserIdFilterChanged,
}
import glot_frontend/admin/run_logs/list_model.{Model}
import glot_frontend/admin/ui/cursor_page as admin_cursor_page
import youid/uuid

pub type Model =
  list_model.Model

pub type Msg =
  list_message.Msg

const page_limit = 25

pub fn init() -> #(Model, admin_effect.Command(Msg)) {
  #(
    Model(
      page: loadable.NotLoaded,
      outcome_filter: run_log_dto.AllRunLogs,
      request_id_filter: "",
      session_id_filter: "",
      user_id_filter: "",
      language_filter: "all",
      applied_request_id_filter: option.None,
      applied_session_id_filter: option.None,
      applied_user_id_filter: option.None,
      applied_language_filter: option.None,
      request_id_error: option.None,
      session_id_error: option.None,
      user_id_error: option.None,
      language_error: option.None,
      request_generation: cursor_request.initial(),
    ),
    admin_effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, admin_effect.Command(Msg)) {
  case model.page {
    loadable.NotLoaded -> load_initial(model)
    loadable.Loading | loadable.Loaded(_) | loadable.LoadError(_) -> #(
      model,
      admin_effect.none(),
    )
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, admin_effect.Command(Msg)) {
  let current_generation = cursor_request.generation(model.request_generation)
  case msg {
    LogsLoaded(generation, _) if generation != current_generation -> #(
      model,
      admin_effect.none(),
    )
    LogsLoaded(_, result) ->
      case result {
        _ -> #(
          Model(
            ..model,
            page: admin_cursor_page.page_from_response(
              result,
              fn(response) { response.page },
              "Could not load run logs.",
            ),
          ),
          admin_effect.none(),
        )
      }

    OutcomeFilterSelected(filter) ->
      case filter == model.outcome_filter {
        True -> #(model, admin_effect.none())
        False ->
          load_initial(
            Model(
              ..model,
              outcome_filter: filter,
              request_id_error: option.None,
              session_id_error: option.None,
              user_id_error: option.None,
              language_error: option.None,
            ),
          )
      }

    RequestIdFilterChanged(value) -> #(
      Model(..model, request_id_filter: value, request_id_error: option.None),
      admin_effect.none(),
    )

    SessionIdFilterChanged(value) -> #(
      Model(..model, session_id_filter: value, session_id_error: option.None),
      admin_effect.none(),
    )

    UserIdFilterChanged(value) -> #(
      Model(..model, user_id_filter: value, user_id_error: option.None),
      admin_effect.none(),
    )

    LanguageFilterChanged(value) -> #(
      Model(..model, language_filter: value, language_error: option.None),
      admin_effect.none(),
    )

    ApplyFilters ->
      case parse_uuid_filter(model.request_id_filter, "Request ID") {
        Ok(request_id) ->
          case parse_uuid_filter(model.session_id_filter, "Session ID") {
            Ok(session_id) ->
              case parse_uuid_filter(model.user_id_filter, "User ID") {
                Ok(user_id) ->
                  case parse_language_filter(model.language_filter) {
                    Ok(language_filter) ->
                      load_initial(
                        Model(
                          ..model,
                          applied_request_id_filter: request_id,
                          applied_session_id_filter: session_id,
                          applied_user_id_filter: user_id,
                          applied_language_filter: language_filter,
                          request_id_error: option.None,
                          session_id_error: option.None,
                          user_id_error: option.None,
                          language_error: option.None,
                        ),
                      )
                    Error(message) -> #(
                      Model(
                        ..model,
                        page: loadable.LoadError(message),
                        language_error: option.Some(message),
                      ),
                      admin_effect.none(),
                    )
                  }
                Error(message) -> #(
                  Model(
                    ..model,
                    page: loadable.LoadError(message),
                    user_id_error: option.Some(message),
                  ),
                  admin_effect.none(),
                )
              }
            Error(message) -> #(
              Model(
                ..model,
                page: loadable.LoadError(message),
                session_id_error: option.Some(message),
              ),
              admin_effect.none(),
            )
          }
        Error(message) -> #(
          Model(
            ..model,
            page: loadable.LoadError(message),
            request_id_error: option.Some(message),
          ),
          admin_effect.none(),
        )
      }

    NextPageClicked ->
      admin_cursor_page.next_page(
        model,
        model.page,
        fn(model, page) { Model(..model, page: page) },
        load_page,
        page_limit,
      )

    PreviousPageClicked ->
      admin_cursor_page.previous_page(
        model,
        model.page,
        fn(model, page) { Model(..model, page: page) },
        load_page,
        page_limit,
      )
  }
}

fn load_initial(model: Model) -> #(Model, admin_effect.Command(Msg)) {
  admin_cursor_page.load_initial(
    model,
    fn(model, page) { Model(..model, page: page) },
    load_page,
    page_limit,
  )
}

fn load_page(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> #(Model, admin_effect.Command(Msg)) {
  let #(request_generation, generation) =
    cursor_request.begin(model.request_generation)
  let model = Model(..model, request_generation: request_generation)
  #(
    model,
    admin_effect.get_admin_run_logs(
      run_log_dto.ListRunLogsRequest(
        pagination: pagination,
        request_id: model.applied_request_id_filter,
        session_id: model.applied_session_id_filter,
        user_id: model.applied_user_id_filter,
        language: model.applied_language_filter,
        outcome_filter: model.outcome_filter,
      ),
      fn(result) { LogsLoaded(generation, result) },
    ),
  )
}

fn parse_uuid_filter(
  value: String,
  label: String,
) -> Result(option.Option(uuid.Uuid), String) {
  let trimmed = string.trim(value)

  case trimmed == "" {
    True -> Ok(option.None)
    False ->
      case uuid.from_string(trimmed) {
        Ok(id) -> Ok(option.Some(id))
        Error(_) -> Error(label <> " must be a valid UUID.")
      }
  }
}

fn parse_language_filter(
  value: String,
) -> Result(option.Option(language.Language), String) {
  case value {
    "all" -> Ok(option.None)
    selected ->
      case language.from_string(selected) {
        option.Some(language) -> Ok(option.Some(language))
        option.None -> Error("Language must be a known runtime.")
      }
  }
}
