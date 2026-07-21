import gleam/option
import glot_core/admin/job_dto
import glot_core/loadable
import glot_core/pagination_model
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/cursor_request
import glot_frontend/admin/jobs/list_message.{
  JobTypeFilterSelected, JobsLoaded, NextPageClicked, PreviousPageClicked,
  StatusFilterSelected,
}
import glot_frontend/admin/jobs/list_model.{Model}
import glot_frontend/admin/ui/cursor_page as admin_cursor_page
import glot_frontend/api/response as api_response

const page_limit = 25

pub fn init() -> #(Model, admin_effect.Command(Msg)) {
  #(
    Model(
      page: loadable.NotLoaded,
      summary: job_dto.empty_summary(),
      status_filter: job_dto.AllStatuses,
      job_type_filter: option.None,
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
    JobsLoaded(generation, _) if generation != current_generation -> #(
      model,
      admin_effect.none(),
    )
    JobsLoaded(_, result) ->
      case result {
        api_response.Success(response) -> #(
          Model(
            ..model,
            page: admin_cursor_page.page_from_response(
              result,
              fn(response) { response.page },
              "Could not load jobs.",
            ),
            summary: response.summary,
          ),
          admin_effect.none(),
        )
        api_response.ApiFailure(_) | api_response.HttpFailure(_) -> #(
          Model(
            ..model,
            page: admin_cursor_page.page_from_response(
              result,
              fn(response) { response.page },
              "Could not load jobs.",
            ),
          ),
          admin_effect.none(),
        )
      }

    StatusFilterSelected(filter) ->
      case filter == model.status_filter {
        True -> #(model, admin_effect.none())
        False -> load_initial(Model(..model, status_filter: filter))
      }

    JobTypeFilterSelected(filter) -> {
      let next_filter = job_type_filter_value(filter)

      case next_filter == model.job_type_filter {
        True -> #(model, admin_effect.none())
        False -> load_initial(Model(..model, job_type_filter: next_filter))
      }
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
    admin_effect.get_admin_jobs(
      job_dto.ListJobsRequest(
        pagination: pagination,
        status_filter: model.status_filter,
        job_type_filter: model.job_type_filter,
        periodic_job_id: option.None,
      ),
      fn(result) { JobsLoaded(generation, result) },
    ),
  )
}

fn job_type_filter_value(value: String) -> option.Option(String) {
  case value {
    "all" -> option.None
    job_type -> option.Some(job_type)
  }
}

pub type Model =
  list_model.Model

pub type Msg =
  list_message.Msg
