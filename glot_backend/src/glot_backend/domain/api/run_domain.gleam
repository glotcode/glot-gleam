import gleam/dynamic
import gleam/option
import glot_backend/api_action
import glot_backend/context
import glot_backend/domain/generic/rate_limit_domain
import glot_backend/domain/generic/session_domain
import glot_backend/effect.{type Free}
import glot_backend/log
import glot_core/run

pub fn run(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> Free(run.RunResult) {
  use request <- effect.and_then(effect.decode_json(
    json_body,
    run.run_request_decoder(),
  ))

  use maybe_session <- effect.and_then(session_domain.get_session(ctx))
  let maybe_session_id = option.map(maybe_session, fn(s) { s.id })

  use user_action_cmd <- effect.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.map(maybe_session, fn(s) { s.user.id }),
    action: api_action.RunAction,
  ))

  use result <- effect.and_then(effect.post_run_request(ctx.config, request))
  use _ <- effect.and_then(effect.run_command(user_action_cmd))

  use _ <- effect.and_then(
    effect.info(
      log.from_list([
        log.string("image", request.image),
        log.optional_uuid("session_id", maybe_session_id),
      ]),
    ),
  )

  effect.succeed(result)
}
