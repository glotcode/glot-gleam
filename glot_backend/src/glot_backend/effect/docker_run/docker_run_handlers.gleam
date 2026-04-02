import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/string
import glot_backend/context
import glot_backend/effect/error
import glot_backend/http_client
import glot_core/run

pub type DockerRunHandlers {
  DockerRunHandlers(
    post_run_request: fn(context.Config, run.RunRequest) ->
      Result(run.RunResult, error.RunRequestError),
  )
}

pub fn from_context(_ctx: context.Context) -> DockerRunHandlers {
  DockerRunHandlers(post_run_request: post_run_request)
}

pub fn post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> Result(run.RunResult, error.RunRequestError) {
  http_client.post_json(
    url: cfg.docker_run.base_url <> "/run",
    body: run.encode_run_request(request),
    headers: dict.from_list([#("X-Access-Token", cfg.docker_run.access_token)]),
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
