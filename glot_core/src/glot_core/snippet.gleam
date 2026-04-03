import gleam/dynamic/decode
import gleam/json
import gleam/option
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

pub type GetSnippetRequest {
  GetSnippetRequest(id: Uuid)
}

pub fn get_decoder() -> decode.Decoder(GetSnippetRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  decode.success(GetSnippetRequest(id: id))
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
  SnippetResponse(snippet: Snippet, is_owner: Bool)
}

pub fn encode_response(response: SnippetResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(response.snippet.id))),
    #("userId", json.string(uuid.to_string(response.snippet.user_id))),
    #("title", json.string(response.snippet.data.title)),
    #("language", language.encode(response.snippet.data.language)),
    #("visibility", encode_visibility(response.snippet.data.visibility)),
    #("stdin", json.string(response.snippet.data.stdin)),
    #("runCommand", json.string(response.snippet.data.run_command)),
    #("files", json.array(response.snippet.data.files, encode_file)),
    #("createdAt", timestamp_helpers.encode(response.snippet.created_at)),
    #("updatedAt", timestamp_helpers.encode(response.snippet.updated_at)),
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

pub fn visibility_from_string(visibility: String) -> option.Option(Visibility) {
  case visibility {
    "public" -> option.Some(Public)
    "unlisted" -> option.Some(Unlisted)
    _ -> option.None
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
