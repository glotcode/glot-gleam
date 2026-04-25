import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/user_model.{type HydratedUser}
import youid/uuid.{type Uuid}

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

pub type HydratedSession {
  HydratedSession(identity: Session, user: HydratedUser)
}
