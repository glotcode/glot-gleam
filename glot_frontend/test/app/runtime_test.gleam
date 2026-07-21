import gleam/option
import gleam/time/timestamp
import gleeunit
import glot_core/auth/session_dto
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_frontend/app/runtime
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn authenticated_visible_runtime_requests_first_heartbeat_test() {
  let now = timestamp.from_unix_seconds(1000)
  let model =
    runtime.Model(
      session: runtime.AuthenticatedSession(test_session()),
      now:,
      page_visible: True,
      heartbeat_in_flight: False,
      last_heartbeat_at: option.None,
      heartbeat_interval_seconds: 60,
    )

  let #(next, should_refresh) = runtime.tick(model, now, True)

  assert should_refresh
  assert next.heartbeat_in_flight
  assert next.last_heartbeat_at == option.Some(now)
}

pub fn in_flight_heartbeat_is_not_started_twice_test() {
  let now = timestamp.from_unix_seconds(1000)
  let model =
    runtime.Model(
      session: runtime.AuthenticatedSession(test_session()),
      now:,
      page_visible: True,
      heartbeat_in_flight: True,
      last_heartbeat_at: option.None,
      heartbeat_interval_seconds: 60,
    )

  let #(_, should_refresh) = runtime.tick(model, now, True)

  assert !should_refresh
}

fn test_session() {
  let created_at = timestamp.from_unix_seconds(1)
  session_dto.SessionResponse(
    id: uuid.v7(),
    user: session_dto.SessionUserResponse(
      id: uuid.v7(),
      email: email_address_model.EmailAddress("test@example.com"),
      username: "test-user",
      role: user_model.RegularUser,
    ),
    created_at:,
  )
}
