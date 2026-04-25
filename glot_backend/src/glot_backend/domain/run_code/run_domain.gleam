import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/docker_run/docker_run_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/run

pub fn run(
  ctx: context.Context,
  request: run.RunRequest,
) -> program_types.Program(run.RunResult) {
  use maybe_session <- program.and_then(session_domain.get_session(ctx))
  let maybe_session_id = option.map(maybe_session, fn(s) { s.identity.id })
  let maybe_user = option.map(maybe_session, fn(session) { session.user })

  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.RunAction,
    actor: api_action_policy_domain.actor_from_user(maybe_user),
  ))

  use result <- program.and_then(docker_run_effect.run_code(ctx.config, request))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.string("image", request.image),
        log.optional_uuid("session_id", maybe_session_id),
      ]),
    ),
  )

  program.succeed(result)
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(run.RunRequest) {
  program.decode_dynamic(data, run.run_request_decoder())
}
