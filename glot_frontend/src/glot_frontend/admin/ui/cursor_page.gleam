import gleam/option
import glot_core/loadable
import glot_core/pagination_model
import glot_frontend/admin/command as admin_effect
import glot_frontend/api/response as api_response

pub fn ensure_loaded(
  state: loadable.Loadable(pagination_model.CursorPage(a)),
  load_effect: admin_effect.Command(msg),
) -> #(
  loadable.Loadable(pagination_model.CursorPage(a)),
  admin_effect.Command(msg),
) {
  case state {
    loadable.NotLoaded -> #(loadable.Loading, load_effect)
    loadable.Loading | loadable.Loaded(_) | loadable.LoadError(_) -> #(
      state,
      admin_effect.none(),
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
    #(model, admin_effect.Command(msg)),
  limit: Int,
) -> #(model, admin_effect.Command(msg)) {
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
    #(model, admin_effect.Command(msg)),
  limit: Int,
) -> #(model, admin_effect.Command(msg)) {
  case pagination_model.next_cursor(current_page(state)) {
    option.Some(cursor) ->
      load_page(
        update_page(model, loadable.Loading),
        pagination_model.AfterPage(cursor: cursor, limit: limit),
      )
    option.None -> #(model, admin_effect.none())
  }
}

pub fn previous_page(
  model: model,
  state: loadable.Loadable(pagination_model.CursorPage(a)),
  update_page: fn(model, loadable.Loadable(pagination_model.CursorPage(a))) ->
    model,
  load_page: fn(model, pagination_model.CursorPagination) ->
    #(model, admin_effect.Command(msg)),
  limit: Int,
) -> #(model, admin_effect.Command(msg)) {
  case pagination_model.previous_cursor(current_page(state)) {
    option.Some(cursor) ->
      load_page(
        update_page(model, loadable.Loading),
        pagination_model.BeforePage(cursor: cursor, limit: limit),
      )
    option.None -> #(model, admin_effect.none())
  }
}

pub fn page_from_response(
  result: api_response.Response(response),
  to_page: fn(response) -> pagination_model.CursorPage(a),
  http_error: String,
) -> loadable.Loadable(pagination_model.CursorPage(a)) {
  case result {
    api_response.Success(response) -> loadable.Loaded(to_page(response))
    api_response.ApiFailure(error) ->
      loadable.LoadError(api_response.error_message(error))
    api_response.HttpFailure(_) -> loadable.LoadError(http_error)
  }
}
