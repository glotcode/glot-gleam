import gleam/option
import gleam/string
import glot_core/language
import glot_core/snippet/snippet_model
import glot_frontend/public/editor/draft
import glot_frontend/public/editor/draft_persistence
import glot_frontend/public/editor/draft_repository

const day_ms = 86_400_000

pub fn new_and_existing_drafts_have_stable_separate_storage_keys_test() {
  assert draft_persistence.storage_key(draft_persistence.NewSnippet(
      "javascript",
    ))
    == "glot.editor.draft.new.javascript"
  assert draft_persistence.storage_key(draft_persistence.ExistingSnippet(
      "snippet-1",
    ))
    == "glot.editor.draft.snippet.snippet-1"
}

pub fn stored_draft_round_trip_preserves_every_field_test() {
  let value = fixture()
  let encoded = draft_persistence.encode(value, 1000)
  assert string.contains(encoded, "\"savedAtMs\":1000")
  assert draft_persistence.read(option.Some(encoded), 2000)
    == draft_persistence.UseDraft(draft.StoredEditorDraft(
      draft: value,
      saved_at_ms: 1000,
    ))
}

pub fn missing_storage_value_is_not_a_cleanup_candidate_test() {
  assert draft_persistence.read(option.None, 1000) == draft_persistence.NoDraft
}

pub fn malformed_json_and_invalid_schema_are_cleanup_candidates_test() {
  assert draft_persistence.read(option.Some("{invalid"), 1000)
    == draft_persistence.RemoveStoredDraft
  assert draft_persistence.read(option.Some("{\"savedAtMs\":1000}"), 1000)
    == draft_persistence.RemoveStoredDraft
}

pub fn draft_is_valid_through_retention_boundary_and_removed_after_it_test() {
  let encoded = draft_persistence.encode(fixture(), 1000)
  let assert draft_persistence.UseDraft(_) =
    draft_persistence.read(option.Some(encoded), 1000 + day_ms)
  assert draft_persistence.read(option.Some(encoded), 1000 + day_ms + 1)
    == draft_persistence.RemoveStoredDraft
}

pub fn future_timestamp_is_retained_when_the_client_clock_moves_back_test() {
  let encoded = draft_persistence.encode(fixture(), 2000)
  let assert draft_persistence.UseDraft(stored) =
    draft_persistence.read(option.Some(encoded), 1000)
  assert stored.saved_at_ms == 2000
}

pub fn repository_loads_valid_value_through_injected_storage_test() {
  let encoded = draft_persistence.encode(fixture(), 1000)
  let storage =
    draft_repository.Storage(
      read: fn(key) {
        assert key == "glot.editor.draft.new.javascript"
        option.Some(encoded)
      },
      write: fn(_, _) { False },
      remove: fn(_) { False },
      now_milliseconds: fn() { 2000 },
    )
  let assert option.Some(stored) =
    draft_repository.load(
      draft_persistence.NewSnippet("javascript"),
      using: storage,
    )
  assert stored.draft == fixture()
}

pub fn repository_removes_corrupt_value_even_when_cleanup_fails_test() {
  let storage =
    draft_repository.Storage(
      read: fn(key) {
        assert key == "glot.editor.draft.snippet.corrupt"
        option.Some("invalid")
      },
      write: fn(_, _) { False },
      remove: fn(key) {
        assert key == "glot.editor.draft.snippet.corrupt"
        False
      },
      now_milliseconds: fn() { 2000 },
    )
  assert draft_repository.load(
      draft_persistence.ExistingSnippet("corrupt"),
      using: storage,
    )
    == option.None
}

pub fn repository_removes_expired_value_test() {
  let encoded = draft_persistence.encode(fixture(), 1000)
  let storage =
    draft_repository.Storage(
      read: fn(_) { option.Some(encoded) },
      write: fn(_, _) { False },
      remove: fn(key) {
        assert key == "glot.editor.draft.new.javascript"
        True
      },
      now_milliseconds: fn() { 1000 + day_ms + 1 },
    )
  assert draft_repository.load(
      draft_persistence.NewSnippet("javascript"),
      using: storage,
    )
    == option.None
}

pub fn repository_treats_failed_or_unavailable_reads_as_missing_test() {
  let storage =
    draft_repository.Storage(
      read: fn(_) { option.None },
      write: fn(_, _) { False },
      remove: fn(_) { False },
      now_milliseconds: fn() { 1000 },
    )
  assert draft_repository.load(
      draft_persistence.NewSnippet("javascript"),
      using: storage,
    )
    == option.None
}

pub fn repository_exposes_write_failure_without_losing_serialization_test() {
  let value = fixture()
  let storage =
    draft_repository.Storage(
      read: fn(_) { option.None },
      write: fn(key, encoded) {
        assert key == "glot.editor.draft.snippet.fixture"
        assert draft_persistence.read(option.Some(encoded), 5000)
          == draft_persistence.UseDraft(draft.StoredEditorDraft(
            draft: value,
            saved_at_ms: 5000,
          ))
        False
      },
      remove: fn(_) { False },
      now_milliseconds: fn() { 5000 },
    )
  assert !draft_repository.save(
    draft_persistence.ExistingSnippet("fixture"),
    value,
    using: storage,
  )
}

pub fn repository_exposes_clear_failure_and_uses_the_resolved_key_test() {
  let storage =
    draft_repository.Storage(
      read: fn(_) { option.None },
      write: fn(_, _) { False },
      remove: fn(key) {
        assert key == "glot.editor.draft.new.javascript"
        False
      },
      now_milliseconds: fn() { 1000 },
    )
  assert !draft_repository.clear(
    draft_persistence.NewSnippet("javascript"),
    using: storage,
  )
}

fn fixture() -> draft.EditorDraft {
  draft.EditorDraft(
    title: "Persistence fixture",
    language: language.JavaScript,
    files: [
      snippet_model.File("main.js", "console.log('fixture')"),
      snippet_model.File("helper.js", "export const value = 42"),
    ],
    stdin: option.Some("fixture input"),
    run_instructions_override: option.Some(language.RunInstructions(
      build_commands: ["npm install", "npm run build"],
      run_command: "node dist/main.js",
    )),
  )
}
