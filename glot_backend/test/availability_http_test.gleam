import gleam/erlang/process
import gleam/http
import gleam/http/response as http_response
import gleam/json
import gleam/option
import gleam/regexp
import gleam/string
import gleam/time/timestamp
import gleeunit
import glot_backend/api
import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/file_system
import glot_backend/page
import glot_backend/server_mode
import glot_backend/worker/app_config_cache_worker/worker as app_config_cache_worker
import glot_core/availability_mode
import pog
import wisp/simulate
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn api_returns_503_with_retry_after_in_read_only_mode_test() {
  let availability =
    dynamic_config.AvailabilityConfig(
      mode: availability_mode.ReadOnlyMode,
      message: "Scheduled platform maintenance.",
      retry_after_seconds: option.Some(600),
    )
  let app_config_subject = start_app_config_worker(availability)
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
      test_context(),
      app_config_subject,
      process.new_subject(),
      process.new_subject(),
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

pub fn page_returns_503_with_retry_after_in_maintenance_mode_test() {
  let assert Ok(_) = write_test_manifest()
  let availability =
    dynamic_config.AvailabilityConfig(
      mode: availability_mode.MaintenanceMode,
      message: "Scheduled platform maintenance.",
      retry_after_seconds: option.Some(600),
    )
  let app_config_subject = start_app_config_worker(availability)
  let db = pog.named_connection(process.new_name("availability_http_db"))
  let request = simulate.request(http.Get, "/snippets")

  let response =
    page.handle_request(
      db,
      test_context(),
      app_config_subject,
      process.new_subject(),
      process.new_subject(),
      request,
    )

  assert response.status == 503
  assert http_response.get_header(response, "retry-after") == Ok("600")

  let body = simulate.read_body(response)
  assert string.contains(body, "maintenance-page__shell")
  assert string.contains(body, "/static/glot_frontend.js") == False
  assert string.contains(body, "/static/assets/test-styles.css")
  assert string.contains(body, "Temporarily unavailable")
  assert string.contains(body, "Scheduled platform maintenance.")
  assert string.contains(body, "Please try again in about 10 minute(s).")
}

fn start_app_config_worker(
  availability: dynamic_config.AvailabilityConfig,
) -> process.Subject(app_config_cache_worker.Message) {
  let server_mode_name = process.new_name("availability_http_server_mode")
  let assert Ok(_) = server_mode.start(server_mode_name)
  let server_mode_subject = process.named_subject(server_mode_name)

  let worker_name = process.new_name("availability_http_app_config_worker")
  let assert Ok(_) =
    app_config_cache_worker.start_with_handlers(
      worker_name,
      server_mode_subject,
      app_config_cache_worker.Deps(
        fetch_config: fn() { Ok(test_dynamic_config(availability)) },
        now_ns: fn() { 0 },
      ),
    )

  process.named_subject(worker_name)
}

fn test_dynamic_config(
  availability: dynamic_config.AvailabilityConfig,
) -> dynamic_config.DynamicConfig {
  dynamic_config.DynamicConfig(
    ..dynamic_config.empty(),
    availability: availability,
  )
}

fn test_context() -> context.Context {
  let assert Ok(is_email) = regexp.from_string(".*")

  context.Context(
    config: context.Config(
      app_env: context.Dev,
      encryption_key: "test",
      listening_address: "localhost",
      listening_port: 3000,
      static_base_path: test_static_base_path(),
      postgres: context.PostgresConfig(
        host: "localhost",
        port: 5432,
        db: "test",
        user: "test",
        pass: "test",
        pool_size: 1,
      ),
    ),
    regexes: context.Regexes(is_email: is_email),
    request_id: uuid.nil,
    started_at: 0,
    deadline_at_monotonic_ns: option.None,
    timestamp: timestamp.system_time(),
    client_info: context.empty_client_info(),
  )
}

fn test_static_base_path() -> String {
  "/tmp/glot_backend_availability_http_static"
}

fn write_test_manifest() -> Result(Nil, String) {
  file_system.write_file(
    test_static_base_path() <> "/manifest.json",
    "{\"index.html\":{\"file\":\"assets/test-frontend.js\",\"css\":[\"assets/test-styles.css\"]}}",
  )
}
