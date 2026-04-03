import gleam/time/timestamp.{type Timestamp}
import glot_core/email/email_address_model
import youid/uuid.{type Uuid}

pub type User {
  User(id: Uuid, email: email_address_model.EmailAddress, created_at: Timestamp)
}
