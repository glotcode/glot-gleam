import envoy
import gleam/dict
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/io
import gleam/list
import gleam/option
import gleam/otp/static_supervisor as supervisor
import gleam/regexp
import gleam/string
import gleam/time/timestamp
import glot_backend/api
import glot_backend/context
import glot_backend/erlang
import glot_backend/job_worker
import glot_backend/log_worker
import glot_core/email
import lustre/attribute
import lustre/element
import lustre/element/html
import mist
import pog
import radiate
import wisp
import wisp/wisp_mist
import youid/uuid

pub fn main() {
  // TODO: only in dev mode
  let _ =
    radiate.new()
    |> radiate.add_dir(
      "/Users/petter/dev/Projects/glot-gleam/glot_backend/src/glot_backend",
    )
    |> radiate.on_reload(fn(_state, path) {
      io.println("Change in " <> path <> ", reloading!")
    })
    |> radiate.start()

  wisp.configure_logger()

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
  let assert Ok(is_email) = regexp.from_string(email.pattern)
  let regexes = context.Regexes(is_email)
  let log_worker_name = process.new_name("log_worker")
  let log_worker_subject = process.named_subject(log_worker_name)
  let mist_handler = fn(conn: request.Request(mist.Connection)) {
    wisp_mist.handler(
      fn(req: request.Request(wisp.Connection)) {
        let ctx =
          context.Context(
            db: db,
            config: cfg,
            request_id: uuid.v7(),
            started_at: erlang.perf_counter_ns(),
            timestamp: timestamp.system_time(),
            regexes: regexes,
            client_info: get_client_info(req, conn.body),
          )

        handle_request(ctx, log_worker_subject, req)
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
      mist_builder,
    )

  process.sleep_forever()
}

pub fn handle_request(
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
  req: wisp.Request,
) -> wisp.Response {
  use req <- app_middleware(req, ctx)

  case req.method, wisp.path_segments(req) {
    //Get, [] -> home_page.home_page()
    http.Get, _ -> serve_spa_page()
    http.Post, ["api", "mux"] ->
      api.handle_request(ctx, log_worker_subject, req)
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
  case mist.get_client_info(conn) {
    Ok(client_info) ->
      option.Some(mist.ip_address_to_string(client_info.ip_address))
    Error(_) -> option.None
  }
}

fn app_middleware(
  req: wisp.Request,
  ctx: context.Context,
  next: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(
    req,
    under: "/static",
    from: ctx.config.static_base_path,
  )

  next(req)
}

fn serve_spa_page() -> wisp.Response {
  let html =
    html.html([], [
      html.head([], [
        html.title([], "glot.io"),
        html.script(
          [
            attribute.type_("module"),
            attribute.src("/static/glot_frontend.js"),
          ],
          "",
        ),
      ]),
      html.body([], [html.div([attribute.id("app")], [])]),
    ])

  html
  |> element.to_document_string
  |> wisp.html_response(200)
}

fn start_supervisor_tree(
  pog_config: pog.Config,
  db: pog.Connection,
  config: context.Config,
  regexes: context.Regexes,
  log_worker_name: process.Name(log_worker.Message),
  mist_builder: mist.Builder(mist.Connection, mist.ResponseData),
) {
  supervisor.new(supervisor.RestForOne)
  |> supervisor.add(pog.supervised(pog_config))
  |> supervisor.add(log_worker.supervised(log_worker_name, db))
  |> supervisor.add(job_worker.supervised(db, config, regexes))
  |> supervisor.add(mist.supervised(mist_builder))
  |> supervisor.start
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
