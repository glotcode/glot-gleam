import gleam/dynamic/decode
import gleam/json
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/user_dto
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import glot_core/language
import glot_core/snippet/snippet_model
import youid/uuid.{type Uuid}

pub type GetSnippetRequest {
  GetSnippetRequest(id: Uuid)
}

pub fn get_decoder() -> decode.Decoder(GetSnippetRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  decode.success(GetSnippetRequest(id: id))
}

pub type DeleteSnippetRequest {
  DeleteSnippetRequest(id: Uuid)
}

pub fn delete_decoder() -> decode.Decoder(DeleteSnippetRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  decode.success(DeleteSnippetRequest(id: id))
}

pub type CreateSnippetRequest {
  CreateSnippetRequest(data: SnippetData)
}

pub fn create_decoder() -> decode.Decoder(CreateSnippetRequest) {
  use data <- decode.field("data", data_decoder())
  decode.success(CreateSnippetRequest(data: data))
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
  SnippetResponse(
    id: Uuid,
    slug: String,
    user: user_dto.UserResponse,
    data: SnippetData,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub fn from_snippet(
  snippet: snippet_model.HydratedSnippet,
) -> SnippetResponse {
  SnippetResponse(
    id: snippet.id,
    slug: snippet.slug,
    user: user_dto.from_user(snippet.user),
    data: SnippetData(
      title: snippet.title,
      language: snippet.language,
      visibility: snippet.visibility,
      stdin: snippet.stdin,
      run_command: snippet.run_command,
      files: snippet.files,
    ),
    created_at: snippet.created_at,
    updated_at: snippet.updated_at,
  )
}

pub fn encode_response(response: SnippetResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(response.id))),
    #("slug", json.string(response.slug)),
    #("user", user_dto.encode(response.user)),
    #("userId", json.string(uuid.to_string(response.user.id))),
    #("title", json.string(response.data.title)),
    #("language", language.encode(response.data.language)),
    #("visibility", snippet_model.encode_visibility(response.data.visibility)),
    #("stdin", json.string(response.data.stdin)),
    #("runCommand", json.string(response.data.run_command)),
    #("files", json.array(response.data.files, snippet_model.encode_file)),
    #("createdAt", timestamp_helpers.encode(response.created_at)),
    #("updatedAt", timestamp_helpers.encode(response.updated_at)),
  ])
}

pub type SnippetData {
  SnippetData(
    title: String,
    language: language.Language,
    visibility: snippet_model.Visibility,
    stdin: String,
    run_command: String,
    files: List(snippet_model.File),
  )
}

pub fn data_decoder() -> decode.Decoder(SnippetData) {
  use title <- decode.field("title", decode.string)
  use lang <- decode.field("language", language.decoder())
  use visibility <- decode.field(
    "visibility",
    snippet_model.visibility_decoder(),
  )
  use stdin <- decode.field("stdin", decode.string)
  use run_command <- decode.field("runCommand", decode.string)
  use files <- decode.field("files", decode.list(snippet_model.file_decoder()))

  decode.success(SnippetData(
    title: title,
    language: lang,
    visibility: visibility,
    stdin: stdin,
    run_command: run_command,
    files: files,
  ))
}
