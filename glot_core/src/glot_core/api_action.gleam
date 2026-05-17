import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import glot_core/admin_action
import glot_core/public_action
import glot_core/server_timing_policy

pub type ApiAction {
  PublicAction(public_action.PublicAction)
  AdminAction(admin_action.AdminAction)
}

pub fn public(action: public_action.PublicAction) -> ApiAction {
  PublicAction(action)
}

pub fn admin(action: admin_action.AdminAction) -> ApiAction {
  AdminAction(action)
}

pub fn list() -> List(ApiAction) {
  list.append(
    list.map(public_action.list(), public),
    list.map(admin_action.list(), admin),
  )
}

pub fn decoder() -> decode.Decoder(ApiAction) {
  use action <- decode.then(decode.string)
  case from_string(action) {
    option.Some(action) -> decode.success(action)
    option.None -> decode.failure(public(public_action.RunAction), "ApiAction")
  }
}

pub fn encode(action: ApiAction) -> json.Json {
  action |> to_string |> json.string
}

pub fn to_string(action: ApiAction) -> String {
  case action {
    PublicAction(action) -> public_action.to_string(action)
    AdminAction(action) -> admin_action.to_string(action)
  }
}

pub fn from_string(action: String) -> option.Option(ApiAction) {
  case public_action.from_string(action) {
    option.Some(action) -> option.Some(public(action))
    option.None ->
      admin_action.from_string(action)
      |> option.map(admin)
  }
}

pub fn server_timing_policy(
  action: ApiAction,
) -> server_timing_policy.ServerTimingPolicy {
  case action {
    PublicAction(action) -> public_action.server_timing_policy(action)
    AdminAction(action) -> admin_action.server_timing_policy(action)
  }
}
