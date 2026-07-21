import gleam/json
import gleam/option
import gleam/string
import gleam/time/timestamp
import gleeunit
import glot_core/loadable
import glot_web/page/seo
import glot_web/page/snippets
import lustre/element

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn seo_login_metadata_is_not_indexable_test() {
  assert seo.robots(seo.login()) == "noindex, nofollow"
  assert seo.canonical_url(seo.login()) == "https://glot.io/login"
}

pub fn structured_data_escapes_script_closing_tags_test() {
  let rendered =
    seo.json_ld(json.object([#("name", json.string("</script><script>"))]))
    |> element.to_document_string

  assert !string.contains(rendered, "</script><script>")
  assert string.contains(rendered, "\\u003c/script\\u003e")
}

pub fn snippets_loading_state_hides_table_test() {
  let rendered =
    snippets.ViewModel(
      page: loadable.Loading,
      username: option.None,
      now: timestamp.from_unix_seconds_and_nanoseconds(0, 0),
    )
    |> snippets.view(False)
    |> element.to_document_string

  assert !string.contains(rendered, "snippets-table")
  assert !string.contains(rendered, "snippets-page__empty")
}

pub fn snippets_empty_loaded_state_uses_placeholder_test() {
  let rendered =
    snippets.ViewModel(
      page: loadable.Loaded(snippets.empty_page()),
      username: option.None,
      now: timestamp.from_unix_seconds_and_nanoseconds(0, 0),
    )
    |> snippets.view(False)
    |> element.to_document_string

  assert string.contains(rendered, "snippets-page__empty")
  assert string.contains(rendered, "No public snippets found.")
  assert !string.contains(rendered, "snippets-table")
}
