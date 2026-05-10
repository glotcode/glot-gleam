import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/regexp
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import glot_core/pagination_model
import youid/uuid

pub type ListUsersRequest {
  ListUsersRequest(
    pagination: pagination_model.CursorPagination,
    email: option.Option(String),
    username: option.Option(String),
    id: option.Option(uuid.Uuid),
    role: option.Option(user_model.UserRole),
    account_state: option.Option(account_model.AccountState),
    account_tier: option.Option(account_model.AccountTier),
  )
}

pub type GetUserRequest {
  GetUserRequest(id: uuid.Uuid)
}

pub type UpdateUserRequest {
  UpdateUserRequest(
    id: uuid.Uuid,
    username: String,
    role: user_model.UserRole,
    account_state: account_model.AccountState,
    account_state_reason: option.Option(String),
    account_tier: account_model.AccountTier,
  )
}

pub type UserSummaryResponse {
  UserSummaryResponse(
    id: uuid.Uuid,
    account_id: uuid.Uuid,
    email: email_address_model.EmailAddress,
    username: String,
    role: user_model.UserRole,
    account_state: account_model.AccountState,
    account_tier: account_model.AccountTier,
    last_login_at: Timestamp,
    created_at: Timestamp,
  )
}

pub type UserDetailResponse {
  UserDetailResponse(
    id: uuid.Uuid,
    account_id: uuid.Uuid,
    email: email_address_model.EmailAddress,
    username: String,
    role: user_model.UserRole,
    account_state: account_model.AccountState,
    account_state_reason: option.Option(String),
    account_tier: account_model.AccountTier,
    delete_job_id: option.Option(uuid.Uuid),
    delete_scheduled_at: option.Option(Timestamp),
    last_login_at: Timestamp,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub type ListUsersResponse {
  ListUsersResponse(page: pagination_model.CursorPage(UserSummaryResponse))
}

pub type GetUserResponse {
  GetUserResponse(user: UserDetailResponse)
}

pub type UpdateUserResponse {
  UpdateUserResponse(user: UserDetailResponse)
}

pub fn list_request_decoder() -> decode.Decoder(ListUsersRequest) {
  decode.then(pagination_model.request_decoder(), fn(pagination) {
    use email <- decode.field("email", decode.optional(decode.string))
    use username <- decode.field("username", decode.optional(decode.string))
    use id <- decode.field("id", decode.optional(uuid_helpers.decoder()))
    use role <- decode.field("role", decode.optional(user_role_decoder()))
    use account_state <- decode.field(
      "accountState",
      decode.optional(account_state_decoder()),
    )
    use account_tier <- decode.field(
      "accountTier",
      decode.optional(account_tier_decoder()),
    )
    decode.success(ListUsersRequest(
      pagination: pagination,
      email: email,
      username: username,
      id: id,
      role: role,
      account_state: account_state,
      account_tier: account_tier,
    ))
  })
}

pub fn encode_list_request(request: ListUsersRequest) -> json.Json {
  json.object(
    list.append(pagination_model.encode_request_fields(request.pagination), [
      #("email", json.nullable(request.email, json.string)),
      #("username", json.nullable(request.username, json.string)),
      #("id", json.nullable(request.id, encode_uuid)),
      #("role", json.nullable(request.role, encode_user_role)),
      #(
        "accountState",
        json.nullable(request.account_state, encode_account_state),
      ),
      #("accountTier", json.nullable(request.account_tier, encode_account_tier)),
    ]),
  )
}

pub fn get_request_decoder() -> decode.Decoder(GetUserRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  decode.success(GetUserRequest(id: id))
}

pub fn encode_get_request(request: GetUserRequest) -> json.Json {
  json.object([#("id", encode_uuid(request.id))])
}

pub fn update_request_decoder() -> decode.Decoder(UpdateUserRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use username <- decode.field("username", decode.string)
  use role <- decode.field("role", user_role_decoder())
  use account_state <- decode.field("accountState", account_state_decoder())
  use account_state_reason <- decode.field(
    "accountStateReason",
    decode.optional(decode.string),
  )
  use account_tier <- decode.field("accountTier", account_tier_decoder())
  decode.success(UpdateUserRequest(
    id: id,
    username: username,
    role: role,
    account_state: account_state,
    account_state_reason: account_state_reason,
    account_tier: account_tier,
  ))
}

pub fn encode_update_request(request: UpdateUserRequest) -> json.Json {
  json.object([
    #("id", encode_uuid(request.id)),
    #("username", json.string(request.username)),
    #("role", encode_user_role(request.role)),
    #("accountState", encode_account_state(request.account_state)),
    #(
      "accountStateReason",
      json.nullable(request.account_state_reason, json.string),
    ),
    #("accountTier", encode_account_tier(request.account_tier)),
  ])
}

pub fn list_response_decoder() -> decode.Decoder(ListUsersResponse) {
  use page <- decode.field(
    "page",
    pagination_model.page_decoder("users", user_summary_decoder()),
  )
  decode.success(ListUsersResponse(page: page))
}

pub fn encode_list_response(response: ListUsersResponse) -> json.Json {
  json.object([
    #(
      "page",
      pagination_model.encode_page(response.page, "users", encode_user_summary),
    ),
  ])
}

pub fn get_response_decoder() -> decode.Decoder(GetUserResponse) {
  use user <- decode.field("user", user_detail_decoder())
  decode.success(GetUserResponse(user: user))
}

pub fn encode_get_response(response: GetUserResponse) -> json.Json {
  json.object([#("user", encode_user_detail(response.user))])
}

pub fn update_response_decoder() -> decode.Decoder(UpdateUserResponse) {
  use user <- decode.field("user", user_detail_decoder())
  decode.success(UpdateUserResponse(user: user))
}

pub fn encode_update_response(response: UpdateUserResponse) -> json.Json {
  json.object([#("user", encode_user_detail(response.user))])
}

pub fn from_users(
  page: pagination_model.CursorPage(user_model.HydratedUser),
) -> ListUsersResponse {
  ListUsersResponse(page: pagination_model.map_page(page, from_user_summary))
}

pub fn from_user_detail(user: user_model.HydratedUser) -> GetUserResponse {
  GetUserResponse(user: to_user_detail(user))
}

pub fn from_updated_user(user: user_model.HydratedUser) -> UpdateUserResponse {
  UpdateUserResponse(user: to_user_detail(user))
}

fn from_user_summary(user: user_model.HydratedUser) -> UserSummaryResponse {
  UserSummaryResponse(
    id: user.identity.id,
    account_id: user.identity.account_id,
    email: user.identity.email,
    username: user.identity.username,
    role: user.identity.role,
    account_state: user.account.identity.account_state,
    account_tier: user.account.identity.account_tier,
    last_login_at: user.identity.last_login_at,
    created_at: user.identity.created_at,
  )
}

fn to_user_detail(user: user_model.HydratedUser) -> UserDetailResponse {
  UserDetailResponse(
    id: user.identity.id,
    account_id: user.identity.account_id,
    email: user.identity.email,
    username: user.identity.username,
    role: user.identity.role,
    account_state: user.account.identity.account_state,
    account_state_reason: user.account.identity.account_state_reason,
    account_tier: user.account.identity.account_tier,
    delete_job_id: user.account.identity.delete_job_id,
    delete_scheduled_at: user.account.delete_scheduled_at,
    last_login_at: user.identity.last_login_at,
    created_at: user.identity.created_at,
    updated_at: user.identity.updated_at,
  )
}

fn user_summary_decoder() -> decode.Decoder(UserSummaryResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use account_id <- decode.field("accountId", uuid_helpers.decoder())
  use email <- decode.field("email", email_decoder())
  use username <- decode.field("username", decode.string)
  use role <- decode.field("role", user_role_decoder())
  use account_state <- decode.field("accountState", account_state_decoder())
  use account_tier <- decode.field("accountTier", account_tier_decoder())
  use last_login_at <- decode.field("lastLoginAt", timestamp_helpers.decoder())
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  decode.success(UserSummaryResponse(
    id: id,
    account_id: account_id,
    email: email,
    username: username,
    role: role,
    account_state: account_state,
    account_tier: account_tier,
    last_login_at: last_login_at,
    created_at: created_at,
  ))
}

fn user_detail_decoder() -> decode.Decoder(UserDetailResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use account_id <- decode.field("accountId", uuid_helpers.decoder())
  use email <- decode.field("email", email_decoder())
  use username <- decode.field("username", decode.string)
  use role <- decode.field("role", user_role_decoder())
  use account_state <- decode.field("accountState", account_state_decoder())
  use account_state_reason <- decode.field(
    "accountStateReason",
    decode.optional(decode.string),
  )
  use account_tier <- decode.field("accountTier", account_tier_decoder())
  use delete_job_id <- decode.field(
    "deleteJobId",
    decode.optional(uuid_helpers.decoder()),
  )
  use delete_scheduled_at <- decode.field(
    "deleteScheduledAt",
    decode.optional(timestamp_helpers.decoder()),
  )
  use last_login_at <- decode.field("lastLoginAt", timestamp_helpers.decoder())
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use updated_at <- decode.field("updatedAt", timestamp_helpers.decoder())
  decode.success(UserDetailResponse(
    id: id,
    account_id: account_id,
    email: email,
    username: username,
    role: role,
    account_state: account_state,
    account_state_reason: account_state_reason,
    account_tier: account_tier,
    delete_job_id: delete_job_id,
    delete_scheduled_at: delete_scheduled_at,
    last_login_at: last_login_at,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn encode_user_summary(user: UserSummaryResponse) -> json.Json {
  json.object([
    #("id", encode_uuid(user.id)),
    #("accountId", encode_uuid(user.account_id)),
    #("email", email_address_model.encode(user.email)),
    #("username", json.string(user.username)),
    #("role", encode_user_role(user.role)),
    #("accountState", encode_account_state(user.account_state)),
    #("accountTier", encode_account_tier(user.account_tier)),
    #("lastLoginAt", timestamp_helpers.encode(user.last_login_at)),
    #("createdAt", timestamp_helpers.encode(user.created_at)),
  ])
}

fn encode_user_detail(user: UserDetailResponse) -> json.Json {
  json.object([
    #("id", encode_uuid(user.id)),
    #("accountId", encode_uuid(user.account_id)),
    #("email", email_address_model.encode(user.email)),
    #("username", json.string(user.username)),
    #("role", encode_user_role(user.role)),
    #("accountState", encode_account_state(user.account_state)),
    #(
      "accountStateReason",
      json.nullable(user.account_state_reason, json.string),
    ),
    #("accountTier", encode_account_tier(user.account_tier)),
    #("deleteJobId", json.nullable(user.delete_job_id, encode_uuid)),
    #(
      "deleteScheduledAt",
      json.nullable(user.delete_scheduled_at, timestamp_helpers.encode),
    ),
    #("lastLoginAt", timestamp_helpers.encode(user.last_login_at)),
    #("createdAt", timestamp_helpers.encode(user.created_at)),
    #("updatedAt", timestamp_helpers.encode(user.updated_at)),
  ])
}

fn email_decoder() -> decode.Decoder(email_address_model.EmailAddress) {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  email_address_model.decoder(is_email)
}

fn user_role_decoder() -> decode.Decoder(user_model.UserRole) {
  use value <- decode.then(decode.string)
  case user_model.role_from_string(value) {
    option.Some(role) -> decode.success(role)
    option.None -> decode.failure(user_model.RegularUser, "UserRole")
  }
}

fn encode_user_role(role: user_model.UserRole) -> json.Json {
  json.string(user_model.role_to_string(role))
}

fn account_state_decoder() -> decode.Decoder(account_model.AccountState) {
  use value <- decode.then(decode.string)
  case account_model.account_state_from_string(value) {
    option.Some(account_state) -> decode.success(account_state)
    option.None -> decode.failure(account_model.Active, "AccountState")
  }
}

fn encode_account_state(
  account_state: account_model.AccountState,
) -> json.Json {
  json.string(account_model.account_state_to_string(account_state))
}

fn account_tier_decoder() -> decode.Decoder(account_model.AccountTier) {
  use value <- decode.then(decode.string)
  case account_model.account_tier_from_string(value) {
    option.Some(account_tier) -> decode.success(account_tier)
    option.None -> decode.failure(account_model.FreeTier, "AccountTier")
  }
}

fn encode_account_tier(account_tier: account_model.AccountTier) -> json.Json {
  json.string(account_model.account_tier_to_string(account_tier))
}

fn encode_uuid(id: uuid.Uuid) -> json.Json {
  json.string(uuid.to_string(id))
}
