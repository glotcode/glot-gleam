import gleam/dynamic
import gleam/option
import glot_backend/api_action
import glot_backend/context
import glot_backend/domain/generic/rate_limit_domain
import glot_backend/domain/generic/session_domain
import glot_backend/effect/core/core_effect
import glot_backend/effect/docker_run/docker_run_effect
import glot_backend/effect/program_types
import glot_backend/effect/program
import glot_backend/log
import glot_core/run

pub fn run(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program_types.Program(run.RunResult) {
  use request <- program.and_then(program.decode_json(
    json_body,
    run.run_request_decoder(),
  ))

  use maybe_session <- program.and_then(session_domain.get_session(ctx))
  let maybe_session_id = option.map(maybe_session, fn(s) { s.id })

  use user_action_cmd <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.map(maybe_session, fn(s) { s.user.id }),
    action: api_action.RunAction,
  ))

  use result <- program.and_then(docker_run_effect.post_run_request(
    ctx.config,
    request,
  ))
  use _ <- program.and_then(user_action_cmd)

  use _ <- program.and_then(
    core_effect.info(
      log.from_list([
        log.string("image", request.image),
        log.optional_uuid("session_id", maybe_session_id),
      ]),
    ),
  )

  program.succeed(result)
}
