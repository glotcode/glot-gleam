import glot_core/admin/user_dto
import glot_core/loadable
import glot_core/pagination_model
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/cursor_request
import glot_frontend/admin/ui/cursor_page as admin_cursor_page
import glot_frontend/admin/users/list_filter
import glot_frontend/admin/users/list_message.{
  AccountStateFilterChanged, AccountTierFilterChanged, ApplyFilterClicked,
  ClearFilterClicked, NextPageClicked, PreviousPageClicked, RoleFilterChanged,
  SearchFilterChanged, UsersLoaded,
}
import glot_frontend/admin/users/list_model.{Model}

const page_limit = 25

pub fn init() -> #(Model, admin_effect.Command(Msg)) {
  #(
    Model(
      page: loadable.NotLoaded,
      search_filter: "",
      role_filter: "",
      account_state_filter: "",
      account_tier_filter: "",
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
    UsersLoaded(generation, _) if generation != current_generation -> #(
      model,
      admin_effect.none(),
    )
    UsersLoaded(_, result) ->
      case result {
        _ -> #(
          Model(
            ..model,
            page: admin_cursor_page.page_from_response(
              result,
              fn(response) { response.page },
              "Could not load users.",
            ),
          ),
          admin_effect.none(),
        )
      }

    SearchFilterChanged(value) -> #(
      Model(..model, search_filter: value),
      admin_effect.none(),
    )

    RoleFilterChanged(value) -> #(
      Model(..model, role_filter: value),
      admin_effect.none(),
    )

    AccountStateFilterChanged(value) -> #(
      Model(..model, account_state_filter: value),
      admin_effect.none(),
    )

    AccountTierFilterChanged(value) -> #(
      Model(..model, account_tier_filter: value),
      admin_effect.none(),
    )

    ApplyFilterClicked -> load_initial(model)

    ClearFilterClicked ->
      case list_filter.has_filters(model) {
        True ->
          load_initial(
            Model(
              ..model,
              search_filter: "",
              role_filter: "",
              account_state_filter: "",
              account_tier_filter: "",
            ),
          )
        False -> #(model, admin_effect.none())
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
    admin_effect.get_admin_users(
      user_dto.ListUsersRequest(
        pagination: pagination,
        email: list_filter.email(model.search_filter),
        username: list_filter.username(model.search_filter),
        id: list_filter.user_id(model.search_filter),
        role: list_filter.role(model.role_filter),
        account_state: list_filter.account_state(model.account_state_filter),
        account_tier: list_filter.account_tier(model.account_tier_filter),
      ),
      fn(result) { UsersLoaded(generation, result) },
    ),
  )
}

pub type Model =
  list_model.Model

pub type Msg =
  list_message.Msg
