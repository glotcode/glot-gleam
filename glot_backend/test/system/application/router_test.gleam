import gleam/erlang/process
import gleam/http
import gleam/http/request as http_request
import gleam/json
import glot_backend/system/application/router
import glot_backend/system/lifecycle/server_mode/adapter/worker as server_mode_adapter
import glot_backend/system/lifecycle/server_mode/model as server_mode
import pog
import support/http as http_support
import wisp/simulate

pub fn app_rejects_mismatched_origin_test() {
  let server_mode_subject =
    http_support.start_server_mode(server_mode.Maintenance)
  let request =
    simulate.browser_request(http.Post, "/api/mux")
    |> simulate.json_body(json.object([]))
    |> http_request.set_header("origin", "https://attacker.example")

  let response =
    router.handle_request(
      pog.named_connection(process.new_name("csrf_http_db")),
      http_support.test_context(),
      process.new_subject(),
      process.new_subject(),
      http_support.no_op_log_sink(),
      http_support.no_op_request_tracker(),
      server_mode_adapter.new(server_mode_subject),
      request,
    )

  assert response.status == 400
}

pub fn app_accepts_matching_origin_test() {
  let server_mode_subject =
    http_support.start_server_mode(server_mode.Maintenance)
  let request =
    simulate.browser_request(http.Post, "/api/mux")
    |> simulate.json_body(json.object([]))

  let response =
    router.handle_request(
      pog.named_connection(process.new_name("csrf_http_db")),
      http_support.test_context(),
      process.new_subject(),
      process.new_subject(),
      http_support.no_op_log_sink(),
      http_support.no_op_request_tracker(),
      server_mode_adapter.new(server_mode_subject),
      request,
    )

  assert response.status == 503
}
