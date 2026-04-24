import gleam/dynamic/decode
import gleam/json
import gleam/regexp
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/user_model
import glot_core/email/email_address_model.{type EmailAddress}
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import youid/uuid.{type Uuid}

pub type AccountResponse {
  AccountResponse(
    id: Uuid,
    email: EmailAddress,
    username: String,
    joined_at: Timestamp,
  )
}

pub type UpdateAccountRequest {
  UpdateAccountRequest(username: String)
}

pub fn from_hydrated_user(user: user_model.HydratedUser) -> AccountResponse {
  AccountResponse(
    id: user.identity.id,
    email: user.identity.email,
    username: user.identity.username,
    joined_at: user.identity.created_at,
  )
}

pub fn encode(account: AccountResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(account.id))),
    #("email", email_address_model.encode(account.email)),
    #("username", json.string(account.username)),
    #("joinedAt", timestamp_helpers.encode(account.joined_at)),
  ])
}

pub fn decoder(is_email: regexp.Regexp) -> decode.Decoder(AccountResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use email <- decode.field("email", email_address_model.decoder(is_email))
  use username <- decode.field("username", decode.string)
  use joined_at <- decode.field("joinedAt", timestamp_helpers.decoder())

  decode.success(AccountResponse(id:, email:, username:, joined_at:))
}

pub fn update_decoder() -> decode.Decoder(UpdateAccountRequest) {
  use username <- decode.field("username", decode.string)
  decode.success(UpdateAccountRequest(username:))
}
