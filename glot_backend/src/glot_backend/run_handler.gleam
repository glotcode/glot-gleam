import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/string
import glot_backend/config
import glot_backend/http_client
import glot_core/run
import wisp

pub fn handle_request(cfg: config.Config, req: wisp.Request) -> wisp.Response {
  use json <- wisp.require_json(req)

  case decode.run(json, run.run_request_decoder()) {
    Error(errors) -> {
      decode_errors_to_response(errors)
    }

    Ok(run_request) -> {
      let json2 = run.encode_run_request(run_request)

      let res =
        http_client.post_json(
          url: cfg.docker_run_base_url <> "/run",
          body: json2,
          headers: dict.from_list([
            #("X-Access-Token", cfg.docker_run_access_token),
          ]),
          decoder: run.run_result_decoder(),
        )

      case res {
        Ok(run_result) -> {
          let response_json = run.encode_run_result(run_result)
          wisp.json_response(json.to_string(response_json), 201)
        }

        Error(err) -> {
          let body = error_body(string.inspect(err))
          wisp.json_response(json.to_string(body), 500)
        }
      }
    }
  }
}

fn decode_errors_to_response(errors: List(decode.DecodeError)) -> wisp.Response {
  let messages =
    errors
    |> list.map(fn(error) { string.inspect(error) })
    |> string.join(", ")

  wisp.json_response(json.to_string(error_body(messages)), 400)
}

fn error_body(message: String) -> json.Json {
  json.object([#("message", json.string(message))])
}
