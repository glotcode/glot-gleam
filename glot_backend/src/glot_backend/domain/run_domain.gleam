import gleam/dynamic
import glot_backend/context
import glot_backend/program
import glot_core/run

pub fn handle_run(
  cfg: context.Config,
  json_body: dynamic.Dynamic,
) -> program.Program(run.RunResult) {
  use request <- program.and_then(program.decode_json(
    json_body,
    run.run_request_decoder(),
  ))
  program.post_run_request(cfg, request)
}
