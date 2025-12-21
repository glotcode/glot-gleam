import gleam/erlang/process
import gleam/http.{Get}
import gleam/io
import glot/home_page
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
      "/Users/petter/dev/Projects/glot-gleam/glot_backend/src/glot",
    )
    |> radiate.on_reload(fn(_state, path) {
      io.println("Change in " <> path <> ", reloading!")
    })
    |> radiate.start()

  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  // Set up our database
  let assert Ok(priv_directory) = wisp.priv_directory("glot_backend")
  let static_directory = priv_directory <> "/static"

  let assert Ok(_) =
    handle_request(static_directory, _)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(3000)
    |> mist.start

  process.sleep_forever()
}

fn app_middleware(
  req: Request,
  static_directory: String,
  next: fn(Request) -> Response,
) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: static_directory)

  next(req)
}

fn handle_request(static_directory: String, req: Request) -> Response {
  use req <- app_middleware(req, static_directory)

  case req.method, wisp.path_segments(req) {
    //Get, [] -> home_page.home_page()
    Get, _ -> serve_spa_page()
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
