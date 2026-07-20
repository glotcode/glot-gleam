import gleam/erlang/process
import gleam/http
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/json
import gleam/option
import gleam/string
import glot_backend/api/handler as api
import glot_backend/request_policy/model/config as request_policy_config
import glot_core/availability_mode
import pog
import support/http as http_support
import wisp/simulate

pub fn api_returns_503_with_retry_after_in_read_only_mode_test() {
  let availability =
    request_policy_config.AvailabilityConfig(
      mode: availability_mode.ReadOnlyMode,
      message: "Scheduled platform maintenance.",
      retry_after_seconds: option.Some(600),
    )
  let app_config_subject = http_support.start_app_config_worker(availability)
  let db = pog.named_connection(process.new_name("availability_http_db"))
  let request =
    simulate.request(http.Post, "/api/mux")
    |> simulate.json_body(
      json.object([
        #("action", json.string("create_snippet")),
        #("data", json.object([])),
      ]),
    )

  let response =
    api.handle_request(
      db,
      http_support.test_context(),
      app_config_subject,
      process.new_subject(),
      http_support.no_op_log_sink(),
      request,
    )

  assert response.status == 503
  assert http_response.get_header(response, "retry-after") == Ok("600")

  let body = simulate.read_body(response)
  assert string.contains(body, "\"code\":\"read_only_mode_enabled\"")
  assert string.contains(
    body,
    "\"message\":\"Scheduled platform maintenance.\"",
  )
}

pub fn api_rejects_non_json_content_type_test() {
  let request =
    simulate.request(http.Post, "/api/mux")
    |> simulate.string_body("{}")

  let response =
    api.handle_request(
      pog.named_connection(process.new_name("content_type_http_db")),
      http_support.test_context(),
      process.new_subject(),
      process.new_subject(),
      http_support.no_op_log_sink(),
      request,
    )

  assert response.status == 415
}

pub fn api_accepts_json_content_type_with_charset_test() {
  let availability =
    request_policy_config.AvailabilityConfig(
      mode: availability_mode.ReadOnlyMode,
      message: "Scheduled platform maintenance.",
      retry_after_seconds: option.None,
    )
  let request =
    simulate.request(http.Post, "/api/mux")
    |> simulate.json_body(
      json.object([
        #("action", json.string("create_snippet")),
        #("data", json.object([])),
      ]),
    )
    |> http_request.set_header(
      "content-type",
      "application/json; charset=utf-8",
    )

  let response =
    api.handle_request(
      pog.named_connection(process.new_name("content_type_http_db")),
      http_support.test_context(),
      http_support.start_app_config_worker(availability),
      process.new_subject(),
      http_support.no_op_log_sink(),
      request,
    )

  assert response.status == 503
}
