import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/uuid_helpers
import glot_core/language
import glot_core/snippet/snippet_model.{type HydratedSnippet, type Snippet, type Visibility}
import pog
import youid/uuid

pub type SnippetHandlers {
  SnippetHandlers(
    get_snippet_by_id: fn(BitArray) ->
      Result(option.Option(HydratedSnippet), error.DbQueryError),
    get_snippet_by_slug: fn(String) ->
      Result(option.Option(HydratedSnippet), error.DbQueryError),
    list_snippets: fn(
      List(Visibility),
      List(uuid.Uuid),
      option.Option(String),
      Int,
    ) -> Result(List(HydratedSnippet), error.DbQueryError),
    delete_snippet: fn(BitArray) -> Result(Nil, error.DbCommandError),
    delete_snippets_by_account_id: fn(uuid.Uuid) -> Result(Nil, error.DbCommandError),
    create_snippet: fn(Snippet) -> Result(Nil, error.DbCommandError),
    update_snippet: fn(Snippet) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> SnippetHandlers {
  SnippetHandlers(
    get_snippet_by_id: fn(id) { get_snippet_by_id(db, id) },
    get_snippet_by_slug: fn(slug) { get_snippet_by_slug(db, slug) },
    list_snippets: fn(visibilities, skip_user_ids, cursor_slug, limit) {
      list_snippets(db, visibilities, skip_user_ids, cursor_slug, limit)
    },
    delete_snippet: fn(id) { delete_snippet(db, id) },
    delete_snippets_by_account_id: fn(account_id) {
      delete_snippets_by_account_id(db, account_id)
    },
    create_snippet: fn(snippet) { create_snippet(db, snippet) },
    update_snippet: fn(snippet) { update_snippet(db, snippet) },
  )
}

pub fn get_snippet_by_id(
  db: pog.Connection,
  id: BitArray,
) -> Result(option.Option(HydratedSnippet), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(db, sql.get_snippet_by_id(id), fn(err) {
      error.DbQueryError(string.inspect(err))
    }),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> get_snippet_from_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one snippet row"))
  }
}

pub fn get_snippet_by_slug(
  db: pog.Connection,
  slug: String,
) -> Result(option.Option(HydratedSnippet), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(db, sql.get_snippet_by_slug(slug), fn(err) {
      error.DbQueryError(string.inspect(err))
    }),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> get_snippet_from_slug_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one snippet row"))
  }
}

pub fn list_snippets(
  db: pog.Connection,
  visibilities: List(Visibility),
  skip_user_ids: List(uuid.Uuid),
  cursor_slug: option.Option(String),
  limit: Int,
) -> Result(List(HydratedSnippet), error.DbQueryError) {
  let visibility_strings =
    visibilities
    |> list.map(snippet_model.visibility_to_string)
  let skip_user_id_bits =
    skip_user_ids
    |> list.map(uuid.to_bit_array)

  db_helpers.query(
    db,
    sql.list_snippets(visibility_strings, skip_user_id_bits, cursor_slug, limit),
    fn(err) { error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) {
    returned.rows
    |> list.map(get_snippet_from_list_row)
    |> result.all
  })
}

pub fn create_snippet(
  db: pog.Connection,
  snippet: Snippet,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }
  let run_instructions =
    snippet.run_instructions
    |> option.map(fn(ri) {
      language.encode_run_instructions(ri)
      |> json.to_string
    })

  db_helpers.execute(
    db,
    sql.insert_snippet(
      id: uuid.to_bit_array(snippet.id),
      slug: snippet.slug,
      user_id: uuid.to_bit_array(snippet.user_id),
      language: language.to_string(snippet.language),
      title: snippet.title,
      visibility: snippet_model.visibility_to_string(snippet.visibility),
      stdin: snippet.stdin,
      run_instructions: run_instructions,
      files: json.to_string(json.array(snippet.files, snippet_model.encode_file)),
      created_at: snippet.created_at,
      updated_at: snippet.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_snippet(
  db: pog.Connection,
  id: BitArray,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_snippet(id), to_error)
  |> result.map(fn(_) { Nil })
}

pub fn delete_snippets_by_account_id(
  db: pog.Connection,
  account_id: uuid.Uuid,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_snippets_by_account_id(uuid.to_bit_array(account_id)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn get_snippet_from_row(
  row: sql.GetSnippetById,
) -> Result(HydratedSnippet, error.DbQueryError) {
  use language <- result.try(
    language.from_string(row.language)
    |> option.to_result(error.DbQueryError(
      "Invalid snippet language: " <> row.language,
    )),
  )
  use visibility <- result.try(
    snippet_model.visibility_from_string(row.visibility)
    |> option.to_result(error.DbQueryError(
      "Invalid snippet visibility: " <> row.visibility,
    )),
  )
  use files <- result.try(
    json.parse(row.files, decode.list(snippet_model.file_decoder()))
    |> result.map_error(fn(decode_errors) {
      error.DbQueryError(
        "Invalid snippet files: " <> string.inspect(decode_errors),
      )
    }),
  )
  use run_instructions <- result.try(decode_run_instructions(row.run_instructions))
  use role <- result.try(
    user_model.role_from_string(row.user_role)
    |> option.to_result(error.DbQueryError(
      "Invalid user role: " <> row.user_role,
    )),
  )

  Ok(snippet_model.HydratedSnippet(
    identity: snippet_model.Snippet(
      id: uuid_helpers.from_bit_array(row.id),
      slug: row.slug,
      user_id: uuid_helpers.from_bit_array(row.user_id),
      title: row.title,
      language: language,
      visibility: visibility,
      stdin: row.stdin,
      run_instructions: run_instructions,
      files: files,
      created_at: row.created_at,
      updated_at: row.updated_at,
    ),
    user: user_model.User(
      id: uuid_helpers.from_bit_array(row.user_id),
      account_id: uuid_helpers.from_bit_array(row.user_account_id),
      email: email_address_model.EmailAddress(row.user_email),
      username: row.user_username,
      role: role,
      last_login_at: row.user_last_login_at,
      created_at: row.user_created_at,
      updated_at: row.user_updated_at,
    ),
  ))
}

fn get_snippet_from_slug_row(
  row: sql.GetSnippetBySlug,
) -> Result(HydratedSnippet, error.DbQueryError) {
  use language <- result.try(
    language.from_string(row.language)
    |> option.to_result(error.DbQueryError(
      "Invalid snippet language: " <> row.language,
    )),
  )
  use visibility <- result.try(
    snippet_model.visibility_from_string(row.visibility)
    |> option.to_result(error.DbQueryError(
      "Invalid snippet visibility: " <> row.visibility,
    )),
  )
  use files <- result.try(
    json.parse(row.files, decode.list(snippet_model.file_decoder()))
    |> result.map_error(fn(decode_errors) {
      error.DbQueryError(
        "Invalid snippet files: " <> string.inspect(decode_errors),
      )
    }),
  )
  use run_instructions <- result.try(decode_run_instructions(row.run_instructions))
  use role <- result.try(
    user_model.role_from_string(row.user_role)
    |> option.to_result(error.DbQueryError(
      "Invalid user role: " <> row.user_role,
    )),
  )

  Ok(snippet_model.HydratedSnippet(
    identity: snippet_model.Snippet(
      id: uuid_helpers.from_bit_array(row.id),
      slug: row.slug,
      user_id: uuid_helpers.from_bit_array(row.user_id),
      title: row.title,
      language: language,
      visibility: visibility,
      stdin: row.stdin,
      run_instructions: run_instructions,
      files: files,
      created_at: row.created_at,
      updated_at: row.updated_at,
    ),
    user: user_model.User(
      id: uuid_helpers.from_bit_array(row.user_id),
      account_id: uuid_helpers.from_bit_array(row.user_account_id),
      email: email_address_model.EmailAddress(row.user_email),
      username: row.user_username,
      role: role,
      last_login_at: row.user_last_login_at,
      created_at: row.user_created_at,
      updated_at: row.user_updated_at,
    ),
  ))
}

fn get_snippet_from_list_row(
  row: sql.ListSnippets,
) -> Result(HydratedSnippet, error.DbQueryError) {
  use language <- result.try(
    language.from_string(row.language)
    |> option.to_result(error.DbQueryError(
      "Invalid snippet language: " <> row.language,
    )),
  )
  use visibility <- result.try(
    snippet_model.visibility_from_string(row.visibility)
    |> option.to_result(error.DbQueryError(
      "Invalid snippet visibility: " <> row.visibility,
    )),
  )
  use files <- result.try(
    json.parse(row.files, decode.list(snippet_model.file_decoder()))
    |> result.map_error(fn(decode_errors) {
      error.DbQueryError(
        "Invalid snippet files: " <> string.inspect(decode_errors),
      )
    }),
  )
  use run_instructions <- result.try(decode_run_instructions(row.run_instructions))
  use role <- result.try(
    user_model.role_from_string(row.user_role)
    |> option.to_result(error.DbQueryError(
      "Invalid user role: " <> row.user_role,
    )),
  )

  Ok(snippet_model.HydratedSnippet(
    identity: snippet_model.Snippet(
      id: uuid_helpers.from_bit_array(row.id),
      slug: row.slug,
      user_id: uuid_helpers.from_bit_array(row.user_id),
      title: row.title,
      language: language,
      visibility: visibility,
      stdin: row.stdin,
      run_instructions: run_instructions,
      files: files,
      created_at: row.created_at,
      updated_at: row.updated_at,
    ),
    user: user_model.User(
      id: uuid_helpers.from_bit_array(row.user_id),
      account_id: uuid_helpers.from_bit_array(row.user_account_id),
      email: email_address_model.EmailAddress(row.user_email),
      username: row.user_username,
      role: role,
      last_login_at: row.user_last_login_at,
      created_at: row.user_created_at,
      updated_at: row.user_updated_at,
    ),
  ))
}

pub fn update_snippet(
  db: pog.Connection,
  snippet: Snippet,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }
  let run_instructions =
    snippet.run_instructions
    |> option.map(fn(ri) {
      language.encode_run_instructions(ri)
      |> json.to_string
    })

  db_helpers.execute(
    db,
    sql.update_snippet(
      id: uuid.to_bit_array(snippet.id),
      slug: snippet.slug,
      user_id: uuid.to_bit_array(snippet.user_id),
      language: language.to_string(snippet.language),
      title: snippet.title,
      visibility: snippet_model.visibility_to_string(snippet.visibility),
      stdin: snippet.stdin,
      run_instructions: run_instructions,
      files: json.to_string(json.array(snippet.files, snippet_model.encode_file)),
      created_at: snippet.created_at,
      updated_at: snippet.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn decode_run_instructions(
  run_instructions: option.Option(String),
) -> Result(option.Option(language.RunInstructions), error.DbQueryError) {
  case run_instructions {
    option.Some(value) ->
      case json.parse(value, language.run_instructions_decoder()) {
        Ok(instructions) -> Ok(option.Some(instructions))
        Error(decode_errors) ->
          Error(error.DbQueryError(
            "Invalid snippet run instructions: "
            <> string.inspect(decode_errors),
          ))
      }
    option.None -> Ok(option.None)
  }
}
