import gleam/list
import gleam/option
import gleam/result
import gleam/string

const bootstrap_filename = "0000_bootstrap.sql"

pub type SqlFile {
  SqlFile(version: String, name: String, filename: String)
}

pub fn parse_filename(filename: String) -> Result(#(String, String), String) {
  case is_sql_file(filename) {
    True -> {
      let stem = string.slice(filename, 0, string.length(filename) - 4)

      case string.split_once(stem, "_") {
        Ok(#(version, name)) ->
          case version == "" || name == "" {
            True -> Error("Invalid migration filename: " <> filename)
            False -> Ok(#(version, name))
          }
        Error(Nil) -> Error("Invalid migration filename: " <> filename)
      }
    }
    False -> Error("Invalid migration filename: " <> filename)
  }
}

pub fn decode_filenames(
  filenames: List(String),
) -> Result(List(SqlFile), String) {
  let filenames =
    list.sort(filenames, by: fn(left, right) { string.compare(left, right) })

  decode_filename_entries(filenames, [])
}

pub fn validate_migrations(
  filenames: List(String),
) -> Result(List(SqlFile), String) {
  use files <- result.try(decode_filenames(filenames))
  use _ <- result.try(ensure_unique_versions(files, option.None))

  case files {
    [first, ..] if first.filename == bootstrap_filename -> Ok(files)
    [first, ..] ->
      Error(
        "First migration must be "
        <> bootstrap_filename
        <> ", got "
        <> first.filename,
      )
    [] -> Error("No migrations found")
  }
}

pub fn validate_seeds(
  filenames: List(String),
) -> Result(List(SqlFile), String) {
  use files <- result.try(decode_filenames(filenames))
  ensure_unique_versions(files, option.None)
}

fn decode_filename_entries(
  filenames: List(String),
  acc: List(SqlFile),
) -> Result(List(SqlFile), String) {
  case filenames {
    [] -> Ok(list.reverse(acc))
    [filename, ..rest] -> {
      use #(version, name) <- result.try(parse_filename(filename))
      decode_filename_entries(rest, [SqlFile(version:, name:, filename:), ..acc])
    }
  }
}

fn ensure_unique_versions(
  files: List(SqlFile),
  previous_version: option.Option(String),
) -> Result(List(SqlFile), String) {
  case files {
    [] -> Ok([])
    [file, ..rest] -> {
      case previous_version {
        option.Some(version) if version == file.version ->
          Error("Duplicate migration version: " <> file.version)
        _ -> {
          use validated_rest <- result.try(ensure_unique_versions(
            rest,
            option.Some(file.version),
          ))
          Ok([file, ..validated_rest])
        }
      }
    }
  }
}

fn is_sql_file(filename: String) -> Bool {
  string.ends_with(filename, ".sql")
}
