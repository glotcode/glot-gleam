import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/user_dto
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import glot_core/language
import glot_core/pagination_model
import glot_core/snippet/snippet_model
import youid/uuid

pub type ListSnippetsRequest {
  ListSnippetsRequest(
    pagination: pagination_model.CursorPagination,
    username: option.Option(String),
  )
}

pub type GetSnippetRequest {
  GetSnippetRequest(slug: String)
}

pub type SnippetSummaryResponse {
  SnippetSummaryResponse(
    id: uuid.Uuid,
    slug: String,
    user: user_dto.UserResponse,
    title: String,
    language: language.Language,
    visibility: snippet_model.Visibility,
    file_count: Int,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub type SnippetDetailResponse {
  SnippetDetailResponse(
    id: uuid.Uuid,
    slug: String,
    user: user_dto.UserResponse,
    title: String,
    language: language.Language,
    visibility: snippet_model.Visibility,
    stdin: String,
    run_instructions: option.Option(language.RunInstructions),
    files: List(snippet_model.File),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub type ListSnippetsResponse {
  ListSnippetsResponse(page: pagination_model.CursorPage(SnippetSummaryResponse))
}

pub type GetSnippetResponse {
  GetSnippetResponse(snippet: SnippetDetailResponse)
}

pub fn list_request_decoder() -> decode.Decoder(ListSnippetsRequest) {
  decode.then(pagination_model.request_decoder(), fn(pagination) {
    use username <- decode.field("username", decode.optional(decode.string))
    decode.success(ListSnippetsRequest(pagination: pagination, username: username))
  })
}

pub fn encode_list_request(request: ListSnippetsRequest) -> json.Json {
  json.object(
    list.append(
      pagination_model.encode_request_fields(request.pagination),
      [#("username", json.nullable(request.username, json.string))],
    ),
  )
}

pub fn get_request_decoder() -> decode.Decoder(GetSnippetRequest) {
  use slug <- decode.field("slug", decode.string)
  decode.success(GetSnippetRequest(slug: slug))
}

pub fn encode_get_request(request: GetSnippetRequest) -> json.Json {
  json.object([#("slug", json.string(request.slug))])
}

pub fn list_response_decoder() -> decode.Decoder(ListSnippetsResponse) {
  use page <- decode.field(
    "page",
    pagination_model.page_decoder("snippets", snippet_summary_decoder()),
  )
  decode.success(ListSnippetsResponse(page: page))
}

pub fn encode_list_response(response: ListSnippetsResponse) -> json.Json {
  json.object([
    #(
      "page",
      pagination_model.encode_page(
        response.page,
        "snippets",
        encode_snippet_summary,
      ),
    ),
  ])
}

pub fn get_response_decoder() -> decode.Decoder(GetSnippetResponse) {
  use snippet <- decode.field("snippet", snippet_detail_decoder())
  decode.success(GetSnippetResponse(snippet: snippet))
}

pub fn encode_get_response(response: GetSnippetResponse) -> json.Json {
  json.object([#("snippet", encode_snippet_detail(response.snippet))])
}

pub fn from_snippets(
  page: pagination_model.CursorPage(snippet_model.HydratedSnippet),
) -> ListSnippetsResponse {
  ListSnippetsResponse(page: pagination_model.map_page(page, from_snippet_summary))
}

pub fn from_snippet(
  snippet: snippet_model.HydratedSnippet,
) -> GetSnippetResponse {
  GetSnippetResponse(snippet: to_snippet_detail(snippet))
}

fn from_snippet_summary(
  snippet: snippet_model.HydratedSnippet,
) -> SnippetSummaryResponse {
  SnippetSummaryResponse(
    id: snippet.identity.id,
    slug: snippet.identity.slug,
    user: user_dto.from_user(snippet.user),
    title: snippet.identity.title,
    language: snippet.identity.language,
    visibility: snippet.identity.visibility,
    file_count: list.length(snippet.identity.files),
    created_at: snippet.identity.created_at,
    updated_at: snippet.identity.updated_at,
  )
}

fn to_snippet_detail(
  snippet: snippet_model.HydratedSnippet,
) -> SnippetDetailResponse {
  SnippetDetailResponse(
    id: snippet.identity.id,
    slug: snippet.identity.slug,
    user: user_dto.from_user(snippet.user),
    title: snippet.identity.title,
    language: snippet.identity.language,
    visibility: snippet.identity.visibility,
    stdin: snippet.identity.stdin,
    run_instructions: snippet.identity.run_instructions,
    files: snippet.identity.files,
    created_at: snippet.identity.created_at,
    updated_at: snippet.identity.updated_at,
  )
}

fn snippet_summary_decoder() -> decode.Decoder(SnippetSummaryResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use slug <- decode.field("slug", decode.string)
  use user <- decode.field("user", user_dto.user_decoder())
  use title <- decode.field("title", decode.string)
  use snippet_language <- decode.field("language", language.decoder())
  use visibility <- decode.field(
    "visibility",
    snippet_model.visibility_decoder(),
  )
  use file_count <- decode.field("fileCount", decode.int)
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use updated_at <- decode.field("updatedAt", timestamp_helpers.decoder())
  decode.success(SnippetSummaryResponse(
    id: id,
    slug: slug,
    user: user,
    title: title,
    language: snippet_language,
    visibility: visibility,
    file_count: file_count,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn encode_snippet_summary(response: SnippetSummaryResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(response.id))),
    #("slug", json.string(response.slug)),
    #("user", user_dto.encode(response.user)),
    #("title", json.string(response.title)),
    #("language", language.encode(response.language)),
    #("visibility", snippet_model.encode_visibility(response.visibility)),
    #("fileCount", json.int(response.file_count)),
    #("createdAt", timestamp_helpers.encode(response.created_at)),
    #("updatedAt", timestamp_helpers.encode(response.updated_at)),
  ])
}

fn snippet_detail_decoder() -> decode.Decoder(SnippetDetailResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use slug <- decode.field("slug", decode.string)
  use user <- decode.field("user", user_dto.user_decoder())
  use title <- decode.field("title", decode.string)
  use snippet_language <- decode.field("language", language.decoder())
  use visibility <- decode.field(
    "visibility",
    snippet_model.visibility_decoder(),
  )
  use stdin <- decode.field("stdin", decode.string)
  use run_instructions <- decode.field(
    "runInstructions",
    decode.optional(language.run_instructions_decoder()),
  )
  use files <- decode.field("files", decode.list(snippet_model.file_decoder()))
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use updated_at <- decode.field("updatedAt", timestamp_helpers.decoder())
  decode.success(SnippetDetailResponse(
    id: id,
    slug: slug,
    user: user,
    title: title,
    language: snippet_language,
    visibility: visibility,
    stdin: stdin,
    run_instructions: run_instructions,
    files: files,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn encode_snippet_detail(response: SnippetDetailResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(response.id))),
    #("slug", json.string(response.slug)),
    #("user", user_dto.encode(response.user)),
    #("title", json.string(response.title)),
    #("language", language.encode(response.language)),
    #("visibility", snippet_model.encode_visibility(response.visibility)),
    #("stdin", json.string(response.stdin)),
    #(
      "runInstructions",
      json.nullable(
        response.run_instructions,
        language.encode_run_instructions,
      ),
    ),
    #("files", json.array(response.files, snippet_model.encode_file)),
    #("createdAt", timestamp_helpers.encode(response.created_at)),
    #("updatedAt", timestamp_helpers.encode(response.updated_at)),
  ])
}
