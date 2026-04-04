import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_core/email/email_address_model
import youid/uuid.{type Uuid}

pub type User {
  User(
    id: Uuid,
    email: email_address_model.EmailAddress,
    username: Option(String),
    first_login_at: Option(Timestamp),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}
