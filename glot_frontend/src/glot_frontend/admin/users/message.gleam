import glot_core/admin/user_dto
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  UserLoaded(api_response.Response(user_dto.GetUserResponse))
  UsernameChanged(String)
  RoleChanged(String)
  AccountStateChanged(String)
  AccountStateReasonChanged(String)
  AccountTierChanged(String)
  ResetClicked
  SaveClicked
  DeleteClicked
  DeleteCancelled
  DeleteDialogClosed
  DeleteConfirmed
  SaveFinished(Generation, api_response.Response(user_dto.UpdateUserResponse))
  DeleteFinished(Generation, api_response.Response(Nil))
}
