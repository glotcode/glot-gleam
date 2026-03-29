import gleam/dynamic
import glot_backend/context
import glot_backend/domain/generic/session_domain
import glot_backend/program

pub fn snippet_create(
  ctx: context.Context,
  _json_body: dynamic.Dynamic,
) -> program.Program(Nil) {
  use _session <- program.and_then(session_domain.require_session(ctx))

  program.succeed(Nil)
}
