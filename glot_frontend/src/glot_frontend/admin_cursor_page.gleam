import gleam/option
import glot_core/pagination_model
import glot_frontend/api
import glot_frontend/loadable
import lustre/effect.{type Effect, none}

pub fn ensure_loaded(
  state: loadable.Loadable(pagination_model.CursorPage(a)),
  load_effect: Effect(msg),
) -> #(loadable.Loadable(pagination_model.CursorPage(a)), Effect(msg)) {
  case state {
    loadable.NotLoaded -> #(loadable.Loading, load_effect)
    loadable.Loading | loadable.Loaded(_) | loadable.LoadError(_) -> #(
      state,
      none(),
    )
  }
}

pub fn current_page(
  state: loadable.Loadable(pagination_model.CursorPage(a)),
) -> pagination_model.CursorPage(a) {
  case state {
    loadable.Loaded(page) -> page
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) ->
      pagination_model.InitialCursorPage(items: [], next_cursor: option.None)
  }
}

pub fn load_initial(
  model: model,
  update_page: fn(model, loadable.Loadable(pagination_model.CursorPage(a))) ->
    model,
  load_page: fn(model, pagination_model.CursorPagination) ->
    #(model, Effect(msg)),
  limit: Int,
) -> #(model, Effect(msg)) {
  load_page(
    update_page(model, loadable.Loading),
    pagination_model.InitialPage(limit: limit),
  )
}

pub fn next_page(
  model: model,
  state: loadable.Loadable(pagination_model.CursorPage(a)),
  update_page: fn(model, loadable.Loadable(pagination_model.CursorPage(a))) ->
    model,
  load_page: fn(model, pagination_model.CursorPagination) ->
    #(model, Effect(msg)),
  limit: Int,
) -> #(model, Effect(msg)) {
  case pagination_model.next_cursor(current_page(state)) {
    option.Some(cursor) ->
      load_page(
        update_page(model, loadable.Loading),
        pagination_model.AfterPage(cursor: cursor, limit: limit),
      )
    option.None -> #(model, none())
  }
}

pub fn previous_page(
  model: model,
  state: loadable.Loadable(pagination_model.CursorPage(a)),
  update_page: fn(model, loadable.Loadable(pagination_model.CursorPage(a))) ->
    model,
  load_page: fn(model, pagination_model.CursorPagination) ->
    #(model, Effect(msg)),
  limit: Int,
) -> #(model, Effect(msg)) {
  case pagination_model.previous_cursor(current_page(state)) {
    option.Some(cursor) ->
      load_page(
        update_page(model, loadable.Loading),
        pagination_model.BeforePage(cursor: cursor, limit: limit),
      )
    option.None -> #(model, none())
  }
}

pub fn page_from_response(
  result: api.ApiResponse(response),
  to_page: fn(response) -> pagination_model.CursorPage(a),
  http_error: String,
) -> loadable.Loadable(pagination_model.CursorPage(a)) {
  case result {
    api.ApiSuccess(response) -> loadable.Loaded(to_page(response))
    api.ApiFailure(error) -> loadable.LoadError(error.message)
    api.HttpFailure(_) -> loadable.LoadError(http_error)
  }
}
