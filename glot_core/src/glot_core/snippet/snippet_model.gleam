import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option
import gleam/result
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

const title_max_length = 200

const stdin_max_length = 20_000

const run_command_max_length = 2000

const build_command_max_length = 2000

const file_name_max_length = 255

const file_content_max_length = 100_000

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

pub fn validate_fields(
  title: String,
  stdin: String,
  run_instructions: option.Option(language.RunInstructions),
  files: List(File),
) -> Result(Nil, String) {
  use _ <- result.try(validate_non_empty("title", title))
  use _ <- result.try(validate_max_length("title", title, title_max_length))
  use _ <- result.try(validate_max_length("stdin", stdin, stdin_max_length))
  use _ <- result.try(validate_run_instructions(run_instructions))
  validate_files(files)
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

fn validate_run_instructions(
  run_instructions: option.Option(language.RunInstructions),
) -> Result(Nil, String) {
  case run_instructions {
    option.None -> Ok(Nil)
    option.Some(instructions) -> {
      use _ <- result.try(validate_non_empty(
        "runInstructions.runCommand",
        instructions.run_command,
      ))
      use _ <- result.try(validate_max_length(
        "runInstructions.runCommand",
        instructions.run_command,
        run_command_max_length,
      ))
      validate_build_commands(instructions.build_commands, 0)
    }
  }
}

fn validate_build_commands(
  commands: List(String),
  index: Int,
) -> Result(Nil, String) {
  case commands {
    [] -> Ok(Nil)
    [command, ..rest] -> {
      let field =
        "runInstructions.buildCommands[" <> int.to_string(index) <> "]"

      use _ <- result.try(validate_non_empty(field, command))
      use _ <- result.try(validate_max_length(
        field,
        command,
        build_command_max_length,
      ))
      validate_build_commands(rest, index + 1)
    }
  }
}

fn validate_files(files: List(File)) -> Result(Nil, String) {
  case files {
    [] -> Error("files must contain at least one file")
    _ -> validate_file_lengths(files, 0)
  }
}

fn validate_file_lengths(files: List(File), index: Int) -> Result(Nil, String) {
  case files {
    [] -> Ok(Nil)
    [file, ..rest] -> {
      use _ <- result.try(validate_non_empty(
        "files[" <> int.to_string(index) <> "].name",
        file.name,
      ))
      use _ <- result.try(validate_max_length(
        "files[" <> int.to_string(index) <> "].name",
        file.name,
        file_name_max_length,
      ))
      use _ <- result.try(validate_max_length(
        "files[" <> int.to_string(index) <> "].content",
        file.content,
        file_content_max_length,
      ))
      validate_file_lengths(rest, index + 1)
    }
  }
}

fn validate_non_empty(field: String, value: String) -> Result(Nil, String) {
  case string.trim(value) == "" {
    True -> Error(field <> " must not be empty")
    False -> Ok(Nil)
  }
}

fn validate_max_length(
  field: String,
  value: String,
  max_length: Int,
) -> Result(Nil, String) {
  case string.length(value) <= max_length {
    True -> Ok(Nil)
    False ->
      Error(
        field
        <> " must be at most "
        <> int.to_string(max_length)
        <> " characters",
      )
  }
}
