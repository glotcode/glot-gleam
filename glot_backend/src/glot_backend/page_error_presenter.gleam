import gleam/int
import gleam/option
import gleam/string
import glot_backend/effect/error
import glot_backend/effect/program_state
import glot_backend/page_layout
import glot_backend/page_response
import glot_core/route
import lustre/attribute
import lustre/element
import lustre/element/html
import wisp

pub fn unavailable_page_response(
  state: program_state.State,
  stylesheet_href: String,
  message: String,
  retry_after_seconds: option.Option(Int),
) -> page_response.PageResponse {
  let response =
    wisp.html_response(
      page_layout.document(
        title: "glot.io - unavailable",
        head_children: [],
        include_frontend: False,
        stylesheet_href: stylesheet_href,
        frontend_src: "",
        app_attributes: [attribute.class("maintenance-page")],
        app_children: [
          html.main([attribute.class("maintenance-page__shell")], [
            html.section([attribute.class("maintenance-page__panel")], [
              html.p([attribute.class("maintenance-page__eyebrow")], [
                html.text("Availability mode"),
              ]),
              html.h1([attribute.class("maintenance-page__title")], [
                html.text("Temporarily unavailable"),
              ]),
              html.p([attribute.class("maintenance-page__message")], [
                html.text(message),
              ]),
              availability_retry_after_view(retry_after_seconds),
              html.div([attribute.class("maintenance-page__actions")], [
                html.a(
                  [
                    attribute.class("maintenance-page__link"),
                    route.href(route.Public(route.Login)),
                  ],
                  [html.text("Login")],
                ),
                html.a(
                  [
                    attribute.class("maintenance-page__link"),
                    route.href(route.Admin(route.AdminHome)),
                  ],
                  [html.text("Admin")],
                ),
              ]),
            ]),
          ]),
        ],
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

fn availability_retry_after_view(
  retry_after_seconds: option.Option(Int),
) -> element.Element(Nil) {
  case retry_after_seconds {
    option.Some(seconds) ->
      html.p([attribute.class("maintenance-page__message")], [
        html.text(
          "Please try again in about " <> retry_after_text(seconds) <> ".",
        ),
      ])
    option.None ->
      html.p([attribute.class("maintenance-page__message")], [
        html.text("Please try again shortly."),
      ])
  }
}

fn retry_after_text(seconds: Int) -> String {
  case seconds >= 3600 {
    True -> int.to_string(seconds / 3600) <> " hour(s)"
    False ->
      case seconds >= 60 {
        True -> int.to_string(seconds / 60) <> " minute(s)"
        False -> int.to_string(seconds) <> " second(s)"
      }
  }
}
