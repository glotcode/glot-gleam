import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/string
import glot_backend/dynamic_config
import glot_backend/effect/error
import glot_backend/http_client
import glot_core/run

pub type DockerRunHandlers {
  DockerRunHandlers(
    run_code: fn(dynamic_config.DockerRunConfig, run.RunRequest, Int) ->
      Result(run.RunResult, error.RunRequestError),
  )
}

pub fn new() -> DockerRunHandlers {
  DockerRunHandlers(run_code: run_code)
}

pub fn run_code(
  cfg: dynamic_config.DockerRunConfig,
  request: run.RunRequest,
  timeout_ms: Int,
) -> Result(run.RunResult, error.RunRequestError) {
  http_client.post_json(
    url: cfg.base_url <> "/run",
    body: run.encode_run_request(request),
    headers: dict.from_list([#("X-Access-Token", cfg.access_token)]),
    timeout_ms: timeout_ms,
    decoder: run.run_result_decoder(),
  )
  |> result.map_error(map_run_http_error)
}

fn map_run_http_error(err: http_client.HttpError) -> error.RunRequestError {
  case err {
    http_client.BadStatus(status: _, body: body) ->
      case json.parse(body, run_error_message_decoder()) {
        Ok(message) -> error.PublicRunRequestError(message)
        Error(_) -> error.InternalRunRequestError(string.inspect(err))
      }
    _ -> error.InternalRunRequestError(string.inspect(err))
  }
}

fn run_error_message_decoder() -> decode.Decoder(String) {
  use message <- decode.field("message", decode.string)
  decode.success(message)
}
