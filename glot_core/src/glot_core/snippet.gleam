import gleam/dynamic/decode
import gleam/json
import gleam/time/timestamp.{type Timestamp}
import glot_core/language
import glot_core/timestamp_helpers
import glot_core/uuid_helpers
import youid/uuid.{type Uuid}

pub type Snippet {
  Snippet(
    id: Uuid,
    user_id: Uuid,
    data: SnippetData,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub type SnippetData {
  SnippetData(
    title: String,
    language: language.Language,
    visibility: Visibility,
    stdin: String,
    run_command: String,
    files: List(File),
  )
}

pub fn data_decoder() -> decode.Decoder(SnippetData) {
  use title <- decode.field("title", decode.string)
  use lang <- decode.field("language", language.decoder())
  use visibility <- decode.field("visibility", visibility_decoder())
  use stdin <- decode.field("stdin", decode.string)
  use run_command <- decode.field("runCommand", decode.string)
  use files <- decode.field("files", decode.list(file_decoder()))
  decode.success(SnippetData(
    title: title,
    language: lang,
    visibility: visibility,
    stdin: stdin,
    run_command: run_command,
    files: files,
  ))
}

pub type UpdateSnippetRequest {
  UpdateSnippetRequest(id: Uuid, data: SnippetData)
}

pub fn update_decoder() -> decode.Decoder(UpdateSnippetRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use data <- decode.field("data", data_decoder())
  decode.success(UpdateSnippetRequest(id: id, data: data))
}

pub type SnippetResponse {
  SnippetResponse(data: Snippet, is_owner: Bool)
}

pub fn encode_response(response: SnippetResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(response.data.id))),
    #("userId", json.string(uuid.to_string(response.data.user_id))),
    #("title", json.string(response.data.data.title)),
    #("language", language.encode(response.data.data.language)),
    #("visibility", encode_visibility(response.data.data.visibility)),
    #("stdin", json.string(response.data.data.stdin)),
    #("runCommand", json.string(response.data.data.run_command)),
    #("files", json.array(response.data.data.files, encode_file)),
    #("createdAt", timestamp_helpers.encode(response.data.created_at)),
    #("updatedAt", timestamp_helpers.encode(response.data.updated_at)),
    #("isOwner", json.bool(response.is_owner)),
  ])
}

pub type Visibility {
  Public
  Unlisted
}

pub fn visibility_to_string(visibility: Visibility) -> String {
  case visibility {
    Public -> "public"
    Unlisted -> "unlisted"
  }
}

pub fn encode_visibility(visibility: Visibility) -> json.Json {
  json.string(visibility_to_string(visibility))
}

pub fn visibility_decoder() -> decode.Decoder(Visibility) {
  use visibility <- decode.then(decode.string)
  case visibility {
    "public" -> decode.success(Public)
    "unlisted" -> decode.success(Unlisted)
    _ -> decode.failure(Public, "Visibility")
  }
}

pub type File {
  File(name: String, content: String)
}

pub fn encode_file(file: File) -> json.Json {
  json.object([
    #("name", json.string(file.name)),
    #("content", json.string(file.content)),
  ])
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
