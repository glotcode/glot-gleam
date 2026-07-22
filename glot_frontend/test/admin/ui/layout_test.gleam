import gleam/string
import glot_frontend/admin/ui/layout
import lustre/element

pub fn summary_and_detail_values_use_description_list_markup_test() {
  let summary =
    layout.summary_card("Outcome", "Successful")
    |> element.to_document_string
  let detail =
    layout.detail_item("Request ID", "fixture")
    |> element.to_document_string

  assert string.contains(summary, "<dl")
  assert string.contains(summary, "<dt")
  assert string.contains(summary, "<dd")
  assert !string.contains(summary, "<article")
  assert !string.contains(summary, "<strong")
  assert string.contains(detail, "<dl")
  assert string.contains(detail, "<dt")
  assert string.contains(detail, "<dd")
}
