import glot_backend/effect/error
import glot_backend/effect/error/auth_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import youid/uuid.{type Uuid}

pub fn require_owner(
  actor_user_id: Uuid,
  owner_user_id: Uuid,
) -> program_types.Program(Nil) {
  case actor_user_id == owner_user_id {
    True -> program.succeed(Nil)
    False -> program.fail(error.auth(auth_error.NotOwner))
  }
}
