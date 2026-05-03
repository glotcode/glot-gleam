import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/auth/session_model
import glot_core/auth/user_model

pub fn require_admin(
  session: session_model.HydratedSession,
) -> program_types.Program(Nil) {
  case session.user.identity.role == user_model.AdminUser {
    True -> program.succeed(Nil)
    False -> program.fail(error.AuthorizationError(error.AdminRequiredError))
  }
}
