import gleam/option
import gleam/string
import glot_core/admin/snippet_dto
import glot_core/loadable
import glot_core/pagination_model
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/cursor_request
import glot_frontend/admin/snippets/list_message.{
  ApplyFilterClicked, ClearFilterClicked, NextPageClicked, PreviousPageClicked,
  SnippetsLoaded, UsernameFilterChanged,
}
import glot_frontend/admin/snippets/list_model.{Model}
import glot_frontend/admin/ui/cursor_page as admin_cursor_page

pub type Model =
  list_model.Model

pub type Msg =
  list_message.Msg

const page_limit = 25

pub fn init() -> #(Model, admin_effect.Command(Msg)) {
  #(
    Model(
      page: loadable.NotLoaded,
      username_filter: "",
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
    SnippetsLoaded(generation, _) if generation != current_generation -> #(
      model,
      admin_effect.none(),
    )
    SnippetsLoaded(_, result) ->
      case result {
        _ -> #(
          Model(
            ..model,
            page: admin_cursor_page.page_from_response(
              result,
              fn(response) { response.page },
              "Could not load snippets.",
            ),
          ),
          admin_effect.none(),
        )
      }

    UsernameFilterChanged(value) -> #(
      Model(..model, username_filter: value),
      admin_effect.none(),
    )

    ApplyFilterClicked -> load_initial(model)

    ClearFilterClicked ->
      case model.username_filter == "" {
        True -> #(model, admin_effect.none())
        False -> load_initial(Model(..model, username_filter: ""))
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
    admin_effect.get_admin_snippets(
      snippet_dto.ListSnippetsRequest(
        pagination: pagination,
        username: filter_username(model.username_filter),
      ),
      fn(result) { SnippetsLoaded(generation, result) },
    ),
  )
}

fn filter_username(value: String) -> option.Option(String) {
  case string.trim(value) {
    "" -> option.None
    username -> option.Some(username)
  }
}
