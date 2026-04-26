import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/user_model.{type User}
import glot_core/helpers/timestamp_helpers
import glot_core/language
import youid/uuid.{type Uuid}

pub type Snippet {
  Snippet(
    id: Uuid,
    slug: String,
    user_id: Uuid,
    title: String,
    language: language.Language,
    visibility: Visibility,
    stdin: String,
    run_instructions: option.Option(language.RunInstructions),
    files: List(File),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub type HydratedSnippet {
  HydratedSnippet(identity: Snippet, user: User)
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

pub fn new_slug(timestamp: Timestamp) -> String {
  timestamp
  |> timestamp_helpers.to_microseconds
  |> int.to_base36
  |> string.lowercase
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

pub type ListSnippetsFilter {
  ListSnippetsFilter(
    visibilities: List(Visibility),
    usernames: List(String),
    user_ids: List(Uuid),
    skip_user_ids: List(Uuid),
  )
}

pub fn new_filter() -> ListSnippetsFilter {
  ListSnippetsFilter(
    visibilities: [],
    usernames: [],
    user_ids: [],
    skip_user_ids: [],
  )
}

pub fn only_visibilities(
  filter: ListSnippetsFilter,
  visibilities: List(Visibility),
) -> ListSnippetsFilter {
  ListSnippetsFilter(..filter, visibilities: visibilities)
}

pub fn only_usernames(
  filter: ListSnippetsFilter,
  usernames: List(String),
) -> ListSnippetsFilter {
  ListSnippetsFilter(..filter, usernames: usernames)
}

pub fn only_user_ids(
  filter: ListSnippetsFilter,
  user_ids: List(Uuid),
) -> ListSnippetsFilter {
  ListSnippetsFilter(..filter, user_ids: user_ids)
}

pub fn skip_user_ids(
  filter: ListSnippetsFilter,
  skip_user_ids: List(Uuid),
) -> ListSnippetsFilter {
  ListSnippetsFilter(..filter, skip_user_ids: skip_user_ids)
}
