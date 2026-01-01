import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/string
import glot_backend/context
import glot_backend/http_client
import glot_backend/response_helpers
import glot_core/run
import wisp

pub fn handle_request(ctx: context.Context, req: wisp.Request) -> wisp.Response {
  use json_body <- wisp.require_json(req)

  case run(ctx.config, json_body) {
    Ok(run_result) -> {
      let response_json = run.encode_run_result(run_result)
      wisp.json_response(json.to_string(response_json), 201)
    }

    Error(DecodeError(errors)) -> {
      let body = response_helpers.error_body_from_decode_errors(errors)
      wisp.json_response(json.to_string(body), 400)
    }

    Error(HttpError(err)) -> {
      let body = response_helpers.error_body(string.inspect(err))
      wisp.json_response(json.to_string(body), 500)
    }
  }
}

fn run(
  cfg: context.Config,
  json_body: dynamic.Dynamic,
) -> Result(run.RunResult, Error) {
  use run_request <- result.try(
    decode.run(json_body, run.run_request_decoder())
    |> result.map_error(DecodeError),
  )

  http_client.post_json(
    url: cfg.docker_run_base_url <> "/run",
    body: run.encode_run_request(run_request),
    headers: dict.from_list([
      #("X-Access-Token", cfg.docker_run_access_token),
    ]),
    decoder: run.run_result_decoder(),
  )
  |> result.map_error(HttpError)
}

type Error {
  DecodeError(List(decode.DecodeError))
  HttpError(http_client.HttpError)
}
