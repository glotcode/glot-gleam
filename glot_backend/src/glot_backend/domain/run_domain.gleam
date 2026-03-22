import gleam/dynamic
import glot_backend/api_action
import glot_backend/context
import glot_backend/program
import glot_core/rate_limit
import glot_core/run

pub fn handle_run(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program.Program(run.RunResult) {
  use request <- program.and_then(program.decode_json(
    json_body,
    run.run_request_decoder(),
  ))

  use _ <- program.and_then(program.enforce_ip_rate_limit(
    config: rate_limit.Config(time_unit: rate_limit.Daily, max_requests: 100),
    now: ctx.timestamp,
    ip: ctx.client_ip,
    action: api_action.RunAction,
  ))

  program.post_run_request(ctx.config, request)
}
