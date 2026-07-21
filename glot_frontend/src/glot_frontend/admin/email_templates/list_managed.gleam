import glot_core/loadable
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/email_templates/list_message.{TemplatesLoaded}
import glot_frontend/admin/email_templates/list_model.{Model}
import glot_frontend/admin/ui/loadable as loadable_effect
import glot_frontend/api/response as api_response

pub type Model =
  list_model.Model

pub type Msg =
  list_message.Msg

pub fn init() -> #(Model, admin_effect.Command(Msg)) {
  #(Model(templates: loadable.NotLoaded), admin_effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, admin_effect.Command(Msg)) {
  case
    loadable_effect.ensure_loaded(
      model.templates,
      admin_effect.get_admin_email_templates(TemplatesLoaded),
    )
  {
    #(templates, next_effect) -> #(Model(templates: templates), next_effect)
  }
}

pub fn update(_model: Model, msg: Msg) -> #(Model, admin_effect.Command(Msg)) {
  case msg {
    TemplatesLoaded(result) ->
      case result {
        api_response.Success(response) -> #(
          Model(templates: loadable.Loaded(response.templates)),
          admin_effect.none(),
        )
        api_response.ApiFailure(error) -> #(
          Model(
            templates: loadable.LoadError(api_response.error_message(error)),
          ),
          admin_effect.none(),
        )
        api_response.HttpFailure(_) -> #(
          Model(templates: loadable.LoadError("Could not load email templates.")),
          admin_effect.none(),
        )
      }
  }
}
