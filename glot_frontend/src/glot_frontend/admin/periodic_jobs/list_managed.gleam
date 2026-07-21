import glot_core/loadable
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/periodic_jobs/list_message.{
  type Msg, PeriodicJobsLoaded,
}
import glot_frontend/admin/periodic_jobs/list_model.{type Model, Model}
import glot_frontend/admin/ui/loadable as loadable_effect
import glot_frontend/api/response as api_response

pub fn init() -> #(Model, admin_effect.Command(Msg)) {
  #(Model(periodic_jobs: loadable.NotLoaded), admin_effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, admin_effect.Command(Msg)) {
  case
    loadable_effect.ensure_loaded(
      model.periodic_jobs,
      admin_effect.get_admin_periodic_jobs(PeriodicJobsLoaded),
    )
  {
    #(periodic_jobs, next_effect) -> #(
      Model(periodic_jobs: periodic_jobs),
      next_effect,
    )
  }
}

pub fn update(_model: Model, msg: Msg) -> #(Model, admin_effect.Command(Msg)) {
  case msg {
    PeriodicJobsLoaded(result) ->
      case result {
        api_response.Success(response) -> #(
          Model(periodic_jobs: loadable.Loaded(response.periodic_jobs)),
          admin_effect.none(),
        )
        api_response.ApiFailure(error) -> #(
          Model(
            periodic_jobs: loadable.LoadError(api_response.error_message(error)),
          ),
          admin_effect.none(),
        )
        api_response.HttpFailure(_) -> #(
          Model(periodic_jobs: loadable.LoadError(
            "Could not load periodic jobs.",
          )),
          admin_effect.none(),
        )
      }
  }
}
