import gleam/json
import gleam/option
import gleam/string
import gleam/time/timestamp
import gleeunit
import glot_core/auth/user_dto
import glot_core/language
import glot_core/loadable
import glot_core/pagination_model
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_web/page/carbon_ad
import glot_web/page/seo
import glot_web/page/snippets
import lustre/element
import youid/uuid

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

pub fn carbon_ad_renders_as_sandboxed_iframe_test() {
  let rendered =
    carbon_ad.view(container_class: "sponsor", load_ad: True)
    |> element.to_document_string

  assert string.contains(rendered, "src=\"/ads/carbon\"")
  assert string.contains(
    rendered,
    "sandbox=\"allow-scripts allow-popups allow-popups-to-escape-sandbox\"",
  )
  assert !string.contains(rendered, "allow-same-origin")
  assert !string.contains(rendered, "cdn.carbonads.com")
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

pub fn populated_snippets_use_native_table_semantics_and_specific_link_names_test() {
  let assert Ok(user_id) =
    uuid.from_string("00000000-0000-4000-8000-000000000001")
  let now = timestamp.from_unix_seconds(200)
  let snippet =
    snippet_dto.SnippetResponse(
      slug: "fixture",
      user: user_dto.UserResponse(id: user_id, username: "fixture-owner"),
      data: snippet_dto.SnippetData(
        title: "Fixture",
        language: language.JavaScript,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [snippet_model.File("main.js", "")],
      ),
      created_at: timestamp.from_unix_seconds(100),
      updated_at: now,
    )
  let rendered =
    snippets.ViewModel(
      page: loadable.Loaded(pagination_model.InitialCursorPage(
        items: [snippet],
        next_cursor: option.None,
      )),
      username: option.None,
      now:,
    )
    |> snippets.view(False)
    |> element.to_document_string

  assert string.contains(rendered, "<table class=\"snippets-table\"")
  assert string.contains(rendered, "<caption class=\"visually-hidden\"")
  assert string.contains(rendered, "<thead>")
  assert string.contains(rendered, "<tbody class=\"snippets-table__body\"")
  assert string.contains(rendered, "scope=\"col\"")
  assert string.contains(
    rendered,
    "aria-label=\"Filter by user fixture-owner\"",
  )
  assert !string.contains(rendered, "aria-label=\"Filter by user\"")
}
