import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/platform_model.{type Browser, type OperatingSystem}
import glot_core/auth/user_model.{type HydratedUser}
import youid/uuid.{type Uuid}

pub type Session {
  Session(
    id: Uuid,
    user_id: Uuid,
    token: String,
    previous_token: Option(String),
    previous_token_valid_until: Option(Timestamp),
    ip: Option(String),
    os_name: Option(OperatingSystem),
    browser_name: Option(Browser),
    user_agent: Option(String),
    created_at: Timestamp,
    token_updated_at: Timestamp,
    last_activity_at: Timestamp,
  )
}

pub type HydratedSession {
  HydratedSession(identity: Session, user: HydratedUser)
}

pub fn rotate_token(
  session: Session,
  token: String,
  token_updated_at: Timestamp,
  previous_token_valid_until: Timestamp,
) -> Session {
  Session(
    ..session,
    token: token,
    previous_token: option.Some(session.token),
    previous_token_valid_until: option.Some(previous_token_valid_until),
    token_updated_at: token_updated_at,
    last_activity_at: token_updated_at,
  )
}

pub fn touch(session: Session, last_activity_at: Timestamp) -> Session {
  Session(..session, last_activity_at: last_activity_at)
}
