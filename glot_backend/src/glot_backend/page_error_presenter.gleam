import gleam/int
import gleam/option
import gleam/string
import glot_backend/page_response
import glot_backend/page_theme.{type PageTheme}
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_web/page/server
import wisp

pub fn unavailable_page_response(
  state: program_state.State,
  stylesheet_href: String,
  theme: option.Option(PageTheme),
  message: String,
  retry_after_seconds: option.Option(Int),
) -> page_response.PageResponse {
  let response =
    wisp.html_response(
      server.unavailable_document(
        server.RenderConfig(
          theme: option.map(theme, page_theme.to_string),
          stylesheet_href: stylesheet_href,
          additional_stylesheet_hrefs: [],
          frontend_src: "",
          frontend_preloads: [],
        ),
        message,
        retry_after_seconds,
      ),
      503,
    )
  let response = case retry_after_seconds {
    option.Some(seconds) ->
      wisp.set_header(response, "Retry-After", int.to_string(seconds))
    option.None -> response
  }

  page_response.PageResponse(
    response: response,
    status_code: 503,
    render_mode: "unavailable",
    effects: state.effect_measurements,
    info: state.info_fields,
    warnings: state.warning_fields,
    debug: state.debug_fields,
    error: option.None,
  )
}

pub fn internal_page_error(
  page_name: String,
  err: error.Error,
  state: program_state.State,
) -> page_response.PageResponse {
  wisp.log_error(
    "TotalProgram failed unexpectedly for "
    <> page_name
    <> ": "
    <> string.inspect(err),
  )
  page_response.PageResponse(
    response: wisp.html_response("Internal Server Error", 500),
    status_code: 500,
    render_mode: "error",
    effects: state.effect_measurements,
    info: state.info_fields,
    warnings: state.warning_fields,
    debug: state.debug_fields,
    error: option.Some(err),
  )
}
