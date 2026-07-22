import gleam/list
import gleam/string
import wisp

pub type Mode {
  Enforce
  ReportOnly
}

/// The policy is kept as structured directives so sources can be reviewed and
/// changed independently without editing one opaque header value.
pub fn policy() -> String {
  [
    #("default-src", ["'self'"]),
    #("base-uri", ["'self'"]),
    #("connect-src", ["'self'"]),
    #("font-src", ["'self'"]),
    #("form-action", ["'self'"]),
    #("frame-ancestors", ["'none'"]),
    #("img-src", ["'self'", "data:"]),
    #("object-src", ["'none'"]),
    #("script-src", [
      "'self'",
      "https://cdn.carbonads.com",
      "https://srv.carbonads.net",
    ]),
    #("style-src", ["'self'"]),
  ]
  |> list.map(serialize_directive)
  |> string.join("; ")
}

pub fn add(response: wisp.Response, mode: Mode) -> wisp.Response {
  wisp.set_header(response, header_name(mode), policy())
}

fn header_name(mode: Mode) -> String {
  case mode {
    Enforce -> "Content-Security-Policy"
    ReportOnly -> "Content-Security-Policy-Report-Only"
  }
}

fn serialize_directive(directive: #(String, List(String))) -> String {
  let #(name, sources) = directive
  case sources {
    [] -> name
    _ -> name <> " " <> string.join(sources, " ")
  }
}
