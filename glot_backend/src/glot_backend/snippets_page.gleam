import gleam/json
import glot_core/page/footer
import glot_core/page/snippets
import glot_core/page/top_bar
import glot_core/route
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn render(view_model: snippets.ViewModel) -> String {
  let html =
    html.html([attribute.lang("en")], [
      html.head([], [
        html.meta([attribute.charset("utf-8")]),
        html.meta([
          attribute.name("viewport"),
          attribute.content("width=device-width, initial-scale=1"),
        ]),
        html.title([], "glot.io - public snippets"),
        html.link([
          attribute.rel("stylesheet"),
          attribute.href("/static/styles.css"),
        ]),
        html.script(
          [
            attribute.type_("module"),
            attribute.src("/static/glot_frontend.js"),
          ],
          "",
        ),
      ]),
      html.body([], [
        html.div(
          [
            attribute.id("app"),
            attribute.attribute(
              "data-ssr",
              snippets.encode(view_model) |> json.to_string,
            ),
          ],
          [
            html.div([], [
              top_bar.view(initial_top_bar_model()),
              snippets.view(view_model),
              footer.view(account_route: route.Account),
            ]),
          ],
        ),
      ]),
    ])

  html
  |> element.to_document_string
}

fn initial_top_bar_model() -> top_bar.ViewModel(Nil) {
  top_bar.ViewModel(
    current_user_label: "Account",
    account_route: route.Account,
    search_query: "",
    selected_index: 0,
    open_msg: Nil,
    close_msg: Nil,
    search_changed: fn(_) { Nil },
    keydown: fn(_) { Nil },
    submit_msg: Nil,
    sections: top_bar.initial_home_sections(fn(_) { Nil }),
  )
}
