import envoy
import gleam/dict
import gleam/erlang/process
import gleam/http
import gleam/io
import glot_backend/config
import glot_backend/run_handler
import lustre/attribute
import lustre/element
import lustre/element/html
import mist
import radiate
import wisp.{type Request, type Response}
import wisp/wisp_mist

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
  let secret_key_base = wisp.random_string(64)

  let assert Ok(priv_directory) = wisp.priv_directory("glot_backend")
  let static_directory = priv_directory <> "/static"

  let default_env =
    dict.from_list([
      #("STATIC_BASE_PATH", static_directory),
    ])

  let env_values = dict.merge(default_env, envoy.all())

  let assert Ok(cfg) = config.from_dict(env_values)

  let assert Ok(_) =
    handle_request(cfg, _)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(3000)
    |> mist.start

  process.sleep_forever()
}

fn app_middleware(
  req: Request,
  cfg: config.Config,
  next: fn(Request) -> Response,
) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: cfg.static_base_path)

  next(req)
}

fn handle_request(cfg: config.Config, req: Request) -> Response {
  use req <- app_middleware(req, cfg)

  case req.method, wisp.path_segments(req) {
    //Get, [] -> home_page.home_page()
    http.Get, _ -> serve_spa_page()
    http.Post, ["api", "run"] -> run_handler.handle_request(cfg, req)
    _, _ -> wisp.not_found()
  }
}

fn serve_spa_page() -> Response {
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
