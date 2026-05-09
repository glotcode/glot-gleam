import envoy
import exception
import gleam/dict
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/otp/static_supervisor
import gleam/regexp
import gleam/string
import gleam/time/timestamp
import glot_backend/api
import glot_backend/context
import glot_backend/erlang
import glot_backend/helpers/response_helpers
import glot_backend/job_tracker
import glot_backend/page
import glot_backend/request_tracker
import glot_backend/server_mode
import glot_backend/worker/app_config_cache_worker
import glot_backend/worker/db_monitor
import glot_backend/worker/job_worker
import glot_backend/worker/language_version_cache_worker
import glot_backend/worker/log_worker
import glot_core/email/email_address_model
import mist
import pog
import signal_handler
import wisp
import wisp/wisp_mist
import youid/uuid

const drain_poll_interval_ms = 100

const drain_timeout_ms = 30_000

pub fn main() {
  let signal_name = process.new_name("graceful_gleam_sigterm")
  let assert Ok(Nil) = process.register(process.self(), signal_name)
  let signal_subject = process.named_subject(signal_name)

  wisp.configure_logger()
  signal_handler.install(signal_name)

  let assert Ok(priv_directory) = wisp.priv_directory("glot_backend")
  let static_directory = priv_directory <> "/static"

  let default_env =
    dict.from_list([
      #("STATIC_BASE_PATH", static_directory),
    ])

  let env_values = dict.merge(default_env, envoy.all())

  let assert Ok(cfg) = context.config_from_dict(env_values)
  let postgres_pool_name = process.new_name("postgres_pool")
  let postgres_cfg = postgres_config(cfg, postgres_pool_name)
  let db = pog.named_connection(postgres_pool_name)
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  let regexes = context.Regexes(is_email)
  let log_worker_name = process.new_name("log_worker")
  let log_worker_subject = process.named_subject(log_worker_name)
  let job_tracker_name = process.new_name("job_tracker")
  let job_tracker_subject = process.named_subject(job_tracker_name)
  let request_tracker_name = process.new_name("request_tracker")
  let request_tracker_subject = process.named_subject(request_tracker_name)
  let server_mode_name = process.new_name("server_mode")
  let server_mode_subject = process.named_subject(server_mode_name)
  let language_version_cache_worker_name =
    process.new_name("language_version_cache_worker")
  let language_version_cache_subject =
    process.named_subject(language_version_cache_worker_name)
  let app_config_cache_worker_name = process.new_name("app_config_cache_worker")
  let app_config_cache_subject =
    process.named_subject(app_config_cache_worker_name)
  let mist_handler = fn(conn: request.Request(mist.Connection)) {
    wisp_mist.handler(
      fn(req: request.Request(wisp.Connection)) {
        let ctx =
          context.Context(
            config: cfg,
            request_id: uuid.v7(),
            started_at: erlang.perf_counter_ns(),
            timestamp: timestamp.system_time(),
            regexes: regexes,
            client_info: get_client_info(req, conn.body),
          )

        handle_request(
          db,
          ctx,
          app_config_cache_subject,
          language_version_cache_subject,
          log_worker_subject,
          request_tracker_subject,
          server_mode_subject,
          req,
        )
      },
      cfg.encryption_key,
    )(conn)
  }

  let mist_builder =
    mist.new(mist_handler)
    |> mist.port(3000)

  let assert Ok(_) =
    start_supervisor_tree(
      postgres_cfg,
      db,
      cfg,
      regexes,
      log_worker_name,
      job_tracker_name,
      request_tracker_name,
      server_mode_name,
      app_config_cache_worker_name,
      language_version_cache_worker_name,
      mist_builder,
    )

  wait_for_signal(
    signal_subject,
    log_worker_subject,
    server_mode_subject,
    request_tracker_subject,
    job_tracker_subject,
  )
}

type SignalMessage {
  SigtermReceived
}

fn wait_for_signal(
  signal_subject: process.Subject(SignalMessage),
  log_worker_subject: process.Subject(log_worker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
  request_tracker_subject: process.Subject(request_tracker.Message),
  job_tracker_subject: process.Subject(job_tracker.Message),
) -> Nil {
  case process.receive_forever(signal_subject) {
    SigtermReceived -> {
      wisp.log_warning("SIGTERM received")
      server_mode.enter_shutting_down(server_mode_subject)
      wisp.log_warning("Server mode changed to ShuttingDown")
      drain_work(
        request_tracker_subject,
        job_tracker_subject,
        log_worker_subject,
        drain_timeout_ms,
      )
    }
  }
}

fn drain_work(
  request_tracker_subject: process.Subject(request_tracker.Message),
  job_tracker_subject: process.Subject(job_tracker.Message),
  log_worker_subject: process.Subject(log_worker.Message),
  remaining_ms: Int,
) -> Nil {
  let in_flight_request_count =
    request_tracker.get_count(request_tracker_subject)
  let in_flight_job_count = job_tracker.get_count(job_tracker_subject)
  let total_in_flight_count = in_flight_request_count + in_flight_job_count

  case total_in_flight_count == 0 {
    True -> {
      log_worker.drain(log_worker_subject)
      io.println("No in-flight requests, jobs, or logs remain, shutting down")
      erlang.halt()
    }
    False -> {
      case remaining_ms <= 0 {
        True -> {
          io.println(
            "Graceful shutdown timed out with "
            <> int.to_string(in_flight_request_count)
            <> " in-flight requests and "
            <> int.to_string(in_flight_job_count)
            <> " in-flight jobs remaining",
          )
          erlang.halt()
        }
        False -> {
          process.sleep(drain_poll_interval_ms)
          drain_work(
            request_tracker_subject,
            job_tracker_subject,
            log_worker_subject,
            remaining_ms - drain_poll_interval_ms,
          )
        }
      }
    }
  }
}

pub fn handle_request(
  db: pog.Connection,
  ctx: context.Context,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
  log_worker_subject: process.Subject(log_worker.Message),
  request_tracker_subject: process.Subject(request_tracker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
  req: wisp.Request,
) -> wisp.Response {
  use req <- app_middleware(
    req,
    ctx,
    request_tracker_subject,
    server_mode_subject,
  )

  case req.method, wisp.path_segments(req) {
    http.Post, ["api", "mux"] ->
      api.handle_request(
        db,
        ctx,
        app_config_cache_subject,
        language_version_cache_subject,
        log_worker_subject,
        req,
      )
    http.Get, _ ->
      page.handle_request(
        db,
        ctx,
        app_config_cache_subject,
        language_version_cache_subject,
        log_worker_subject,
        req,
      )
    _, _ -> wisp.not_found()
  }
}

fn get_client_info(
  req: wisp.Request,
  conn: mist.Connection,
) -> context.ClientInfo {
  context.ClientInfo(
    session_token: wisp.get_cookie(req, "session", wisp.Signed)
      |> option.from_result(),
    ip: get_header(req, "x-forwarded-for")
      |> option.lazy_or(fn() { get_client_ip(conn) }),
    user_agent: get_header(req, "user-agent"),
    referrer: get_header(req, "referer"),
  )
}

fn get_header(req: wisp.Request, name: String) -> option.Option(String) {
  list.find_map(req.headers, fn(header) {
    let #(header_name, header_value) = header
    case string.lowercase(header_name) == string.lowercase(name) {
      True -> Ok(header_value)
      False -> Error(Nil)
    }
  })
  |> option.from_result()
}

fn get_client_ip(conn: mist.Connection) -> option.Option(String) {
  case mist.get_connection_info(conn) {
    Ok(client_info) ->
      option.Some(mist.ip_address_to_string(client_info.ip_address))
    Error(_) -> option.None
  }
}

fn app_middleware(
  req: wisp.Request,
  ctx: context.Context,
  request_tracker_subject: process.Subject(request_tracker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
  next: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  case server_mode.get_mode(server_mode_subject) {
    server_mode.Maintenance -> maintenance_response()
    server_mode.ShuttingDown -> maintenance_response()
    server_mode.Running -> {
      use <- with_tracked_request(request_tracker_subject)
      use <- wisp.serve_static(
        req,
        under: "/static",
        from: ctx.config.static_base_path,
      )

      next(req)
    }
  }
}

fn with_tracked_request(
  request_tracker_subject: process.Subject(request_tracker.Message),
  next: fn() -> wisp.Response,
) -> wisp.Response {
  request_tracker.request_started(request_tracker_subject)
  use <- exception.defer(fn() {
    request_tracker.request_finished(request_tracker_subject)
  })
  next()
}

fn maintenance_response() -> wisp.Response {
  wisp.json_response(
    json.to_string(response_helpers.error_body(
      "Service temporarily unavailable",
    )),
    503,
  )
}

fn start_supervisor_tree(
  pog_config: pog.Config,
  db: pog.Connection,
  config: context.Config,
  regexes: context.Regexes,
  log_worker_name: process.Name(log_worker.Message),
  job_tracker_name: process.Name(job_tracker.Message),
  request_tracker_name: process.Name(request_tracker.Message),
  server_mode_name: process.Name(server_mode.Message),
  app_config_cache_worker_name: process.Name(app_config_cache_worker.Message),
  language_version_cache_worker_name: process.Name(
    language_version_cache_worker.Message,
  ),
  mist_builder: mist.Builder(mist.Connection, mist.ResponseData),
) {
  static_supervisor.new(static_supervisor.OneForAll)
  |> static_supervisor.add(pog.supervised(pog_config))
  |> static_supervisor.add(server_mode.supervised(server_mode_name))
  |> static_supervisor.add(db_monitor.supervised(
    db,
    process.named_subject(server_mode_name),
  ))
  |> static_supervisor.add(log_worker.supervised(log_worker_name, db))
  |> static_supervisor.add(app_config_cache_worker.supervised(
    app_config_cache_worker_name,
    db,
    process.named_subject(server_mode_name),
  ))
  |> static_supervisor.add(language_version_cache_worker.supervised(
    language_version_cache_worker_name,
    config,
    process.named_subject(app_config_cache_worker_name),
    process.named_subject(server_mode_name),
  ))
  |> static_supervisor.add(request_tracker.supervised(request_tracker_name))
  |> static_supervisor.add(job_tracker.supervised(job_tracker_name))
  |> static_supervisor.add(job_worker.supervised(
    db,
    config,
    regexes,
    process.named_subject(job_tracker_name),
    process.named_subject(server_mode_name),
    process.named_subject(app_config_cache_worker_name),
    process.named_subject(language_version_cache_worker_name),
  ))
  |> static_supervisor.add(mist.supervised(mist_builder))
  |> static_supervisor.start
}

fn postgres_config(
  cfg: context.Config,
  pool_name: process.Name(pog.Message),
) -> pog.Config {
  pog.default_config(pool_name)
  |> pog.host(cfg.postgres.host)
  |> pog.port(cfg.postgres.port)
  |> pog.database(cfg.postgres.db)
  |> pog.user(cfg.postgres.user)
  |> pog.password(option.Some(cfg.postgres.pass))
  |> pog.pool_size(cfg.postgres.pool_size)
}
