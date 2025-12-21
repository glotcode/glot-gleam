import lustre/element
import lustre/element/html
import wisp.{type Response}

pub fn home_page() -> Response {
  let html =
    html.html([], [
      html.head([], [
        html.title([], "glot.io - code playground"),
      ]),
      html.body([], [html.div([], [html.text("glot.io")])]),
    ])

  html
  |> element.to_document_string
  |> wisp.html_response(200)
}
