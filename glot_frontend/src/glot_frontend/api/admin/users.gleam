import glot_core/admin/account_dto as admin_account_dto
import glot_core/admin/user_dto
import glot_core/admin_action
import glot_frontend/api/client
import glot_frontend/api/request
import glot_frontend/api/response
import lustre/effect

pub fn get_admin_users(
  request: user_dto.ListUsersRequest,
  to_msg: fn(response.Response(user_dto.ListUsersResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminUsersAction, request)

  request.send_admin(
    req,
    user_dto.encode_list_request,
    user_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_user(
  request: user_dto.GetUserRequest,
  to_msg: fn(response.Response(user_dto.GetUserResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminUserAction, request)

  request.send_admin(
    req,
    user_dto.encode_get_request,
    user_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn update_admin_user(
  request: user_dto.UpdateUserRequest,
  to_msg: fn(response.Response(user_dto.UpdateUserResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.UpdateAdminUserAction, request)

  request.send_admin(
    req,
    user_dto.encode_update_request,
    user_dto.update_response_decoder(),
    to_msg,
  )
}

pub fn delete_admin_account(
  request: admin_account_dto.DeleteAccountRequest,
  to_msg: fn(response.Response(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.DeleteAdminAccountAction, request)

  request.send_admin(
    req,
    admin_account_dto.encode_delete_request,
    client.nil_decoder(),
    to_msg,
  )
}
