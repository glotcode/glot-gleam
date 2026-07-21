import gleam/dynamic/decode
import gleam/json
import gleam/option
import glot_core/language
import glot_core/snippet/snippet_model

pub type EditorDraft {
  EditorDraft(
    title: String,
    language: language.Language,
    files: List(snippet_model.File),
    stdin: option.Option(String),
    run_instructions_override: option.Option(language.RunInstructions),
  )
}

pub type StoredEditorDraft {
  StoredEditorDraft(draft: EditorDraft, saved_at_ms: Int)
}

const max_draft_age_ms = 86_400_000

pub fn is_expired(saved_at_ms: Int, now_ms: Int) -> Bool {
  now_ms - saved_at_ms > max_draft_age_ms
}

pub fn stored_decoder() -> decode.Decoder(StoredEditorDraft) {
  use saved_at_ms <- decode.field("savedAtMs", decode.int)
  use draft <- decode.field("data", decoder())

  decode.success(StoredEditorDraft(draft: draft, saved_at_ms: saved_at_ms))
}

fn decoder() -> decode.Decoder(EditorDraft) {
  use title <- decode.field("title", decode.string)
  use language <- decode.field("language", language.decoder())
  use files <- decode.field("files", decode.list(snippet_model.file_decoder()))
  use stdin <- decode.field("stdin", decode.optional(decode.string))
  use run_instructions_override <- decode.field(
    "runInstructionsOverride",
    decode.optional(language.run_instructions_decoder()),
  )

  decode.success(EditorDraft(
    title: title,
    language: language,
    files: files,
    stdin: stdin,
    run_instructions_override: run_instructions_override,
  ))
}

pub fn encode(draft: EditorDraft) -> json.Json {
  json.object([
    #("title", json.string(draft.title)),
    #("language", language.encode(draft.language)),
    #("files", json.array(draft.files, snippet_model.encode_file)),
    #("stdin", json.nullable(draft.stdin, json.string)),
    #(
      "runInstructionsOverride",
      json.nullable(
        draft.run_instructions_override,
        language.encode_run_instructions,
      ),
    ),
  ])
}
