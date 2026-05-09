import gleam/dynamic/decode
import gleam/json
import gleam/option
import glot_core/language
import glot_core/snippet/snippet_model
import lustre/effect.{type Effect}

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

pub fn load_new_snippet(
  language_slug: String,
) -> option.Option(StoredEditorDraft) {
  load(load_new_snippet_draft(language_slug, max_draft_age_ms))
}

pub fn save_new_snippet(
  language: language.Language,
  draft: EditorDraft,
) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    write_new_snippet_draft(
      language.to_string(language),
      draft |> encode() |> json.to_string(),
    )
  })
}

pub fn clear_new_snippet(language: language.Language) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    clear_new_snippet_draft(language.to_string(language))
  })
}

pub fn load_existing_snippet(slug: String) -> option.Option(StoredEditorDraft) {
  load(load_existing_snippet_draft(slug, max_draft_age_ms))
}

pub fn save_existing_snippet(slug: String, draft: EditorDraft) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    write_existing_snippet_draft(slug, draft |> encode() |> json.to_string())
  })
}

pub fn clear_existing_snippet(slug: String) -> Effect(msg) {
  effect.from(fn(_dispatch) { clear_existing_snippet_draft(slug) })
}

fn load(raw: String) -> option.Option(StoredEditorDraft) {
  case json.parse(raw, stored_decoder()) {
    Ok(draft) -> option.Some(draft)
    Error(_) -> option.None
  }
}

fn stored_decoder() -> decode.Decoder(StoredEditorDraft) {
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

fn encode(draft: EditorDraft) -> json.Json {
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

@external(javascript, "./editor_draft_ffi.mjs", "loadNewSnippetDraft")
fn load_new_snippet_draft(language_slug: String, max_age_ms: Int) -> String

@external(javascript, "./editor_draft_ffi.mjs", "writeNewSnippetDraft")
fn write_new_snippet_draft(language_slug: String, value: String) -> Nil

@external(javascript, "./editor_draft_ffi.mjs", "clearNewSnippetDraft")
fn clear_new_snippet_draft(language_slug: String) -> Nil

@external(javascript, "./editor_draft_ffi.mjs", "loadExistingSnippetDraft")
fn load_existing_snippet_draft(slug: String, max_age_ms: Int) -> String

@external(javascript, "./editor_draft_ffi.mjs", "writeExistingSnippetDraft")
fn write_existing_snippet_draft(slug: String, value: String) -> Nil

@external(javascript, "./editor_draft_ffi.mjs", "clearExistingSnippetDraft")
fn clear_existing_snippet_draft(slug: String) -> Nil
