import gleam/option
import gleam/string
import glot_core/admin/api_log_dto
import glot_core/loadable
import glot_core/pagination_model
import glot_frontend/admin/api_logs/list_message.{
  ApplyFilters, ErrorFilterSelected, LogsLoaded, NextPageClicked,
  PreviousPageClicked, RequestIdFilterChanged,
}
import glot_frontend/admin/api_logs/list_model.{Model}
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/cursor_request
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
      error_filter: api_log_dto.AllApiLogs,
      request_id_filter: "",
      applied_request_id_filter: option.None,
      request_id_error: option.None,
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
              "Could not load API logs.",
            ),
          ),
          admin_effect.none(),
        )
      }

    ErrorFilterSelected(filter) ->
      case filter == model.error_filter {
        True -> #(model, admin_effect.none())
        False ->
          load_initial(
            Model(..model, error_filter: filter, request_id_error: option.None),
          )
      }

    RequestIdFilterChanged(value) -> #(
      Model(..model, request_id_filter: value, request_id_error: option.None),
      admin_effect.none(),
    )

    ApplyFilters ->
      case parse_uuid_filter(model.request_id_filter, "Request ID") {
        Ok(request_id) ->
          load_initial(
            Model(
              ..model,
              applied_request_id_filter: request_id,
              request_id_error: option.None,
            ),
          )
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
    admin_effect.get_admin_api_logs(
      api_log_dto.ListApiLogsRequest(
        pagination: pagination,
        request_id: model.applied_request_id_filter,
        error_filter: model.error_filter,
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
