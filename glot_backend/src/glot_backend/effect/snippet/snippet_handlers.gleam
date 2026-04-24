import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import gleam/string
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/uuid_helpers
import glot_core/language
import glot_core/snippet/snippet_model.{type HydratedSnippet, type Snippet}
import pog
import youid/uuid

pub type SnippetHandlers {
  SnippetHandlers(
    get_snippet_by_id: fn(BitArray) ->
      Result(option.Option(HydratedSnippet), error.DbQueryError),
    get_snippet_by_slug: fn(String) ->
      Result(option.Option(HydratedSnippet), error.DbQueryError),
    delete_snippet: fn(BitArray) -> Result(Nil, error.DbCommandError),
    create_snippet: fn(Snippet) -> Result(Nil, error.DbCommandError),
    update_snippet: fn(Snippet) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> SnippetHandlers {
  SnippetHandlers(
    get_snippet_by_id: fn(id) { get_snippet_by_id(db, id) },
    get_snippet_by_slug: fn(slug) { get_snippet_by_slug(db, slug) },
    delete_snippet: fn(id) { delete_snippet(db, id) },
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
  use account_state <- result.try(
    account_model.account_state_from_string(row.user_account_state)
    |> option.to_result(error.DbQueryError(
      "Invalid account state: " <> row.user_account_state,
    )),
  )
  use account_tier <- result.try(
    account_model.account_tier_from_string(row.user_account_tier)
    |> option.to_result(error.DbQueryError(
      "Invalid account tier: " <> row.user_account_tier,
    )),
  )

  Ok(snippet_model.HydratedSnippet(
    id: uuid_helpers.from_bit_array(row.id),
    slug: row.slug,
    user: user_model.HydratedUser(
      identity: user_model.User(
        id: uuid_helpers.from_bit_array(row.user_id),
        account_id: uuid_helpers.from_bit_array(row.user_account_id),
        email: email_address_model.EmailAddress(row.user_email),
        username: row.user_username,
        role: role,
        last_login_at: row.user_last_login_at,
        created_at: row.user_created_at,
        updated_at: row.user_updated_at,
      ),
      account: account_model.Account(
        id: uuid_helpers.from_bit_array(row.user_account_id),
        account_state: account_state,
        account_state_reason: row.user_account_state_reason,
        account_tier: account_tier,
        created_at: row.user_created_at,
        updated_at: row.user_updated_at,
      ),
    ),
    title: row.title,
    language: language,
    visibility: visibility,
    stdin: row.stdin,
    run_instructions: run_instructions,
    files: files,
    created_at: row.created_at,
    updated_at: row.updated_at,
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
  use account_state <- result.try(
    account_model.account_state_from_string(row.user_account_state)
    |> option.to_result(error.DbQueryError(
      "Invalid account state: " <> row.user_account_state,
    )),
  )
  use account_tier <- result.try(
    account_model.account_tier_from_string(row.user_account_tier)
    |> option.to_result(error.DbQueryError(
      "Invalid account tier: " <> row.user_account_tier,
    )),
  )

  Ok(snippet_model.HydratedSnippet(
    id: uuid_helpers.from_bit_array(row.id),
    slug: row.slug,
    user: user_model.HydratedUser(
      identity: user_model.User(
        id: uuid_helpers.from_bit_array(row.user_id),
        account_id: uuid_helpers.from_bit_array(row.user_account_id),
        email: email_address_model.EmailAddress(row.user_email),
        username: row.user_username,
        role: role,
        last_login_at: row.user_last_login_at,
        created_at: row.user_created_at,
        updated_at: row.user_updated_at,
      ),
      account: account_model.Account(
        id: uuid_helpers.from_bit_array(row.user_account_id),
        account_state: account_state,
        account_state_reason: row.user_account_state_reason,
        account_tier: account_tier,
        created_at: row.user_created_at,
        updated_at: row.user_updated_at,
      ),
    ),
    title: row.title,
    language: language,
    visibility: visibility,
    stdin: row.stdin,
    run_instructions: run_instructions,
    files: files,
    created_at: row.created_at,
    updated_at: row.updated_at,
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
