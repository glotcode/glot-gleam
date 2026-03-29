import gleam/dynamic/decode
import gleam/json
import glot_core/language

pub type Snippet {
  Snippet(
    title: String,
    language: language.Language,
    visibility: Visibility,
    stdin: String,
    run_command: String,
    files: List(File),
  )
}

pub type Visibility {
  Public
  Unlisted
}

pub type SnippetWithMeta {
  SnippetWithMeta(id: String, is_owner: Bool, snippet: Snippet)
}

pub type File {
  File(name: String, content: String)
}

pub fn encode(snippet: Snippet) -> json.Json {
  json.object([
    #("title", json.string(snippet.title)),
    #("language", language.encode(snippet.language)),
    #("visibility", encode_visibility(snippet.visibility)),
    #("stdin", json.string(snippet.stdin)),
    #("runCommand", json.string(snippet.run_command)),
    #("files", json.array(snippet.files, encode_file)),
  ])
}

pub fn encode_visibility(visibility: Visibility) -> json.Json {
  json.string(visibility_to_string(visibility))
}

pub fn visibility_to_string(visibility: Visibility) -> String {
  case visibility {
    Public -> "public"
    Unlisted -> "unlisted"
  }
}

pub fn encode_file(file: File) -> json.Json {
  json.object([
    #("name", json.string(file.name)),
    #("content", json.string(file.content)),
  ])
}

pub fn decoder() -> decode.Decoder(Snippet) {
  use title <- decode.field("title", decode.string)
  use lang <- decode.field("language", language.decoder())
  use visibility <- decode.field("visibility", visibility_decoder())
  use stdin <- decode.field("stdin", decode.string)
  use run_command <- decode.field("runCommand", decode.string)
  use files <- decode.field("files", decode.list(file_decoder()))
  decode.success(Snippet(
    title: title,
    language: lang,
    visibility: visibility,
    stdin: stdin,
    run_command: run_command,
    files: files,
  ))
}

pub fn visibility_decoder() -> decode.Decoder(Visibility) {
  use visibility <- decode.then(decode.string)
  case visibility {
    "public" -> decode.success(Public)
    "unlisted" -> decode.success(Unlisted)
    _ -> decode.failure(Public, "Visibility")
  }
}

pub fn snippet_with_meta_decoder() -> decode.Decoder(SnippetWithMeta) {
  use id <- decode.field("id", decode.string)
  use is_owner <- decode.field("isOwner", decode.bool)
  use snippet <- decode.field("snippet", decoder())
  decode.success(SnippetWithMeta(id: id, is_owner: is_owner, snippet: snippet))
}

pub fn file_decoder() -> decode.Decoder(File) {
  use name <- decode.field("name", decode.string)
  use content <- decode.field("content", decode.string)
  decode.success(File(name: name, content: content))
}

pub fn default_file(lang: language.Language) -> File {
  File(
    name: language.default_filename(lang),
    content: language.example_code(lang),
  )
}

pub fn empty_file() -> File {
  File(name: "", content: "")
}
