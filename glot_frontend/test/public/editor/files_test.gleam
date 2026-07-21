import gleeunit
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/files

pub fn main() -> Nil {
  gleeunit.main()
}

fn fixtures() -> List(snippet_model.File) {
  [
    snippet_model.File(name: "main.gleam", content: "pub fn main() { Nil }"),
    snippet_model.File(name: "util.gleam", content: "pub const answer = 42"),
  ]
}

pub fn file_updates_preserve_unrelated_entries_test() {
  let updated = files.update_content_at(fixtures(), 1, "pub const answer = 43")

  assert files.content_at(updated, 0) == "pub fn main() { Nil }"
  assert files.content_at(updated, 1) == "pub const answer = 43"
}

pub fn rename_and_remove_are_index_scoped_test() {
  let renamed = files.rename_at(fixtures(), 1, "helpers.gleam")
  assert files.name_at(renamed, 0) == "main.gleam"
  assert files.name_at(renamed, 1) == "helpers.gleam"
  assert files.remove_at(renamed, 0)
    == [
      snippet_model.File(
        name: "helpers.gleam",
        content: "pub const answer = 42",
      ),
    ]
}

pub fn name_validation_enforces_editor_contract_test() {
  assert files.valid_name("main.gleam")
  assert !files.valid_name("")
  assert !files.valid_name("1234567890123456789012345678901")
  assert files.name_exists_except(fixtures(), "main.gleam", 1)
  assert !files.name_exists_except(fixtures(), "main.gleam", 0)
}
