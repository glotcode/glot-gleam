import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import youid/uuid.{type Uuid}

pub type Entry {
  Entry(
    id: Uuid,
    created_at: Timestamp,
    session_id: Option(Uuid),
    user_id: Option(Uuid),
    route: String,
    path: String,
    user_agent: Option(String),
    ip: Option(String),
  )
}
