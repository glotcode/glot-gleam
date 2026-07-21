import gleam/option
import glot_core/admin/user_dto
import glot_core/loadable
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/ui/loadable as loadable_effect
import glot_frontend/admin/users/editor_policy
import glot_frontend/admin/users/message.{UserLoaded}
import glot_frontend/admin/users/model.{type Model, DeleteIdle, Model}
import glot_frontend/api/response as api_response

pub fn ensure_loaded(model: Model) {
  let #(user, next_effect) =
    loadable_effect.ensure_loaded(
      model.user,
      admin_effect.get_admin_user(
        user_dto.GetUserRequest(id: model.id),
        UserLoaded,
      ),
    )
  #(Model(..model, user:), next_effect)
}

pub fn update(model: Model, msg: message.Msg) {
  case msg {
    UserLoaded(result) ->
      case result {
        api_response.Success(response) -> #(
          Model(
            ..model,
            user: loadable.Loaded(editor_policy.from_response(response.user)),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          admin_effect.none(),
        )
        api_response.ApiFailure(error) ->
          failed(model, api_response.error_message(error))
        api_response.HttpFailure(_) -> failed(model, "Could not load user.")
      }
    _ -> #(model, admin_effect.none())
  }
}

fn failed(model: Model, message: String) {
  #(
    Model(
      ..model,
      user: loadable.LoadError(message),
      pending_delete: option.None,
      delete_state: DeleteIdle,
    ),
    admin_effect.none(),
  )
}
