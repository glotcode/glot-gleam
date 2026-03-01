import gleam/dynamic
import glot_backend/program as program
import glot_backend/context
import glot_core/run

pub fn handle_run(
  cfg: context.Config,
  json_body: dynamic.Dynamic,
) -> program.Program(run.RunResult) {
  use request <- program.and_then(program.decode_run_request(json_body))
  program.post_run_request(cfg, request)
}
