import gleam/dynamic
import glot_backend/api_action
import glot_backend/context
import glot_backend/domain/rate_limit_domain
import glot_backend/program
import glot_core/run

pub fn run(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program.Program(run.RunResult) {
  use request <- program.and_then(program.decode_json(
    json_body,
    run.run_request_decoder(),
  ))

  use _ <- program.and_then(rate_limit_domain.enforce_by_ip(
    rate_limits: ctx.config.rate_limits.run,
    now: ctx.timestamp,
    ip: ctx.client_info.ip,
    action: api_action.RunAction,
  ))

  program.post_run_request(ctx.config, request)
}
