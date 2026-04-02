import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_core/user.{type User}
import youid/uuid.{type Uuid}

pub type HydratedSession {
  HydratedSession(
    id: Uuid,
    user: User,
    token: String,
    ip: Option(String),
    user_agent: Option(String),
    created_at: Timestamp,
  )
}

pub type Session {
  Session(
    id: Uuid,
    user_id: Uuid,
    token: String,
    ip: Option(String),
    user_agent: Option(String),
    created_at: Timestamp,
  )
}
