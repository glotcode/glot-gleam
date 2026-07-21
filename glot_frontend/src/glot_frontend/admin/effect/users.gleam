import glot_core/admin/account_dto
import glot_core/admin/user_dto
import glot_frontend/api/response

pub type Command(msg) {
  GetUsers(
    user_dto.ListUsersRequest,
    fn(response.Response(user_dto.ListUsersResponse)) -> msg,
  )
  GetUser(
    user_dto.GetUserRequest,
    fn(response.Response(user_dto.GetUserResponse)) -> msg,
  )
  UpdateUser(
    user_dto.UpdateUserRequest,
    fn(response.Response(user_dto.UpdateUserResponse)) -> msg,
  )
  DeleteAccount(
    account_dto.DeleteAccountRequest,
    fn(response.Response(Nil)) -> msg,
  )
}

pub fn map(command: Command(a), transform: fn(a) -> b) -> Command(b) {
  case command {
    GetUsers(request, complete) ->
      GetUsers(request, fn(result) { transform(complete(result)) })
    GetUser(request, complete) ->
      GetUser(request, fn(result) { transform(complete(result)) })
    UpdateUser(request, complete) ->
      UpdateUser(request, fn(result) { transform(complete(result)) })
    DeleteAccount(request, complete) ->
      DeleteAccount(request, fn(result) { transform(complete(result)) })
  }
}
