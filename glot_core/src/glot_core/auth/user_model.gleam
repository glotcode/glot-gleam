import gleam/time/timestamp.{type Timestamp}
import glot_core/email/email_address_model
import youid/uuid.{type Uuid}

pub type User {
  User(
    id: Uuid,
    email: email_address_model.EmailAddress,
    username: String,
    last_login_at: Timestamp,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub fn mark_last_login(user: User, timestamp: Timestamp) -> User {
  User(..user, last_login_at: timestamp, updated_at: timestamp)
}
