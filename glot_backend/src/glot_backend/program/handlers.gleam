import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action
import glot_backend/context
import glot_backend/crypto_helpers
import glot_backend/db_helpers
import glot_backend/email_message
import glot_backend/http_client
import glot_backend/job
import glot_backend/program
import glot_backend/sql
import glot_core/auth
import glot_core/email
import glot_core/language
import glot_core/rate_limit
import glot_core/run
import glot_core/snippet
import glot_core/user
import glot_core/uuid_helpers
import pog
import youid/uuid

pub fn from_context(ctx: context.Context) -> program.Handlers {
  program.Handlers(
    new_token: crypto_helpers.new_token,
    system_time: timestamp.system_time,
    uuid_v7: fn() { uuid_helpers.v7(ctx.timestamp) },
    post_run_request: post_run_request,
    send_email: send_email,
    get_user_by_email: fn(email) { get_user_by_email(ctx, email) },
    list_login_tokens_by_user: fn(user_id, limit) {
      list_login_tokens_by_user(ctx, user_id, limit)
    },
    get_session_by_token: fn(token) { get_session_by_token(ctx, token) },
    get_next_job: fn(now, pending_status, running_status) {
      get_next_job(ctx, now, pending_status, running_status)
    },
    count_user_activities_by_ip: fn(windows, ip, action) {
      count_user_activities_by_ip(ctx, ip, action, windows)
    },
    count_user_activities_by_user: fn(windows, user_id, action) {
      count_user_activities_by_user(ctx, user_id, action, windows)
    },
    run_command: fn(command) { run_command(ctx.db, command) },
    run_in_transaction: fn(commands) { run_in_transaction(ctx.db, commands) },
  )
}

fn send_email(
  _message: email_message.EmailMessage,
) -> Result(Nil, program.SendEmailError) {
  Error(program.InternalSendEmailError("send_email not implemented"))
}

fn post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> Result(run.RunResult, program.RunRequestError) {
  http_client.post_json(
    url: cfg.docker_run.base_url <> "/run",
    body: run.encode_run_request(request),
    headers: dict.from_list([#("X-Access-Token", cfg.docker_run.access_token)]),
    decoder: run.run_result_decoder(),
  )
  |> result.map_error(map_run_http_error)
}

fn get_user_by_email(
  ctx: context.Context,
  user_email: email.Email,
) -> Result(option.Option(user.User), program.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.get_user_by_email(email.to_string(user_email)),
    fn(err) { program.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { user_from_rows(ctx, returned.rows) })
}

fn list_login_tokens_by_user(
  ctx: context.Context,
  user_id: uuid.Uuid,
  limit: Int,
) -> Result(List(auth.LoginToken), program.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.list_login_tokens_by_user(uuid.to_bit_array(user_id), limit),
    fn(err) { program.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { login_tokens_from_rows(returned.rows) })
}

fn get_session_by_token(
  ctx: context.Context,
  token: String,
) -> Result(option.Option(auth.Session), program.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.get_session_by_token(token),
    fn(err) { program.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { session_from_rows(ctx, returned.rows) })
}

fn user_from_rows(
  ctx: context.Context,
  rows: List(sql.GetUserByEmail),
) -> Result(option.Option(user.User), program.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> user_from_row(ctx, first) |> result.map(option.Some)
    _ -> Error(program.DbQueryError("Expected at most one user row"))
  }
}

fn user_from_row(
  ctx: context.Context,
  row: sql.GetUserByEmail,
) -> Result(user.User, program.DbQueryError) {
  case email.from_string(ctx.regexes.is_email, row.email) {
    option.Some(valid_email) ->
      Ok(user.User(
        id: uuid_helpers.from_bit_array(row.id),
        email: valid_email,
        created_at: row.created_at,
      ))
    option.None ->
      Error(program.DbQueryError(
        "Invalid email format in user row: " <> row.email,
      ))
  }
}

fn login_tokens_from_rows(
  rows: List(sql.ListLoginTokensByUser),
) -> Result(List(auth.LoginToken), program.DbQueryError) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      use token <- result.try(login_token_from_row(first))
      use tokens <- result.try(login_tokens_from_rows(rest))
      Ok([token, ..tokens])
    }
  }
}

fn login_token_from_row(
  row: sql.ListLoginTokensByUser,
) -> Result(auth.LoginToken, program.DbQueryError) {
  Ok(auth.LoginToken(
    id: uuid_helpers.from_bit_array(row.id),
    user_id: uuid_helpers.from_bit_array(row.user_id),
    token: row.token,
    created_at: row.created_at,
    used_at: row.used_at,
  ))
}

fn session_from_rows(
  ctx: context.Context,
  rows: List(sql.GetSessionByToken),
) -> Result(option.Option(auth.Session), program.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> session_from_row(ctx, first) |> result.map(option.Some)
    _ -> Error(program.DbQueryError("Expected at most one session row"))
  }
}

fn session_from_row(
  ctx: context.Context,
  row: sql.GetSessionByToken,
) -> Result(auth.Session, program.DbQueryError) {
  case email.from_string(ctx.regexes.is_email, row.user_email) {
    option.Some(valid_email) ->
      Ok(auth.Session(
        id: uuid_helpers.from_bit_array(row.id),
        user: user.User(
          id: uuid_helpers.from_bit_array(row.user_id),
          email: valid_email,
          created_at: row.user_created_at,
        ),
        token: row.token,
        ip: row.ip,
        user_agent: row.user_agent,
        created_at: row.created_at,
      ))
    option.None ->
      Error(program.DbQueryError(
        "Invalid email format in session row: " <> row.user_email,
      ))
  }
}

fn count_user_activities_by_ip(
  ctx: context.Context,
  ip: option.Option(String),
  action: api_action.ApiAction,
  windows: List(rate_limit.Window),
) -> Result(List(rate_limit.WindowCount), program.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.count_user_activities_by_ip(
      ip: ip,
      action: api_action.to_db_string(action),
      windows: json.array(windows, of: rate_limit.encode_window)
        |> json.to_string(),
    ),
    fn(err) { program.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { window_counts_from_ip_rows(returned.rows) })
}

fn count_user_activities_by_user(
  ctx: context.Context,
  user_id: option.Option(uuid.Uuid),
  action: api_action.ApiAction,
  windows: List(rate_limit.Window),
) -> Result(List(rate_limit.WindowCount), program.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.count_user_activities_by_user(
      user_id: option.map(user_id, uuid.to_bit_array),
      action: api_action.to_db_string(action),
      windows: json.array(windows, of: rate_limit.encode_window)
        |> json.to_string(),
    ),
    fn(err) { program.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { window_counts_from_user_rows(returned.rows) })
}

fn window_counts_from_ip_rows(
  rows: List(sql.CountUserActivitiesByIp),
) -> Result(List(rate_limit.WindowCount), program.DbQueryError) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      use count <- result.try(window_count_from_row(first.unit, first.count))
      use counts <- result.try(window_counts_from_ip_rows(rest))
      Ok([count, ..counts])
    }
  }
}

fn window_counts_from_user_rows(
  rows: List(sql.CountUserActivitiesByUser),
) -> Result(List(rate_limit.WindowCount), program.DbQueryError) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      use count <- result.try(window_count_from_row(first.unit, first.count))
      use counts <- result.try(window_counts_from_user_rows(rest))
      Ok([count, ..counts])
    }
  }
}

fn window_count_from_row(
  unit: String,
  count: Int,
) -> Result(rate_limit.WindowCount, program.DbQueryError) {
  case rate_limit.unit_from_string(unit) {
    option.Some(parsed_unit) ->
      Ok(rate_limit.WindowCount(unit: parsed_unit, count: count))
    option.None ->
      Error(program.DbQueryError(
        "Invalid time unit in rate limit row: " <> unit,
      ))
  }
}

fn get_next_job(
  ctx: context.Context,
  now: Timestamp,
  pending_status: job.Status,
  running_status: job.Status,
) -> Result(option.Option(job.Job), program.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      ctx.db,
      sql.get_next_job(
        job.status_to_string(running_status),
        option.Some(now),
        job.status_to_string(pending_status),
      ),
      fn(err) { program.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> get_job_from_row(row) |> result.map(option.Some)
    _ -> Error(program.DbQueryError("Expected at most one job row"))
  }
}

fn get_job_from_row(
  row: sql.GetNextJob,
) -> Result(job.Job, program.DbQueryError) {
  use status <- result.try(
    job.status_from_string(row.status)
    |> result.map_error(program.DbQueryError),
  )
  use job_type <- result.try(
    job.job_type_from_string(row.job_type)
    |> result.map_error(program.DbQueryError),
  )

  Ok(job.Job(
    id: uuid_helpers.from_bit_array(row.id),
    job_type: job_type,
    payload: row.payload,
    status: status,
    attempts: row.attempts,
    max_attempts: row.max_attempts,
    timeout_seconds: row.timeout_seconds,
    run_at: row.run_at,
    started_at: row.started_at,
    completed_at: row.completed_at,
    last_error: row.last_error,
    created_at: row.created_at,
    updated_at: row.updated_at,
  ))
}

fn run_command(
  db: pog.Connection,
  command: program.DbCommand,
) -> Result(Nil, program.DbCommandError) {
  let to_error = fn(err) { program.DbCommandError(string.inspect(err)) }

  case command {
    program.DbInsertUser(id:, email:, created_at:) ->
      db_helpers.execute(
        db,
        sql.insert_user(uuid.to_bit_array(id), email, created_at),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbInsertJob(job.Job(
      id: id,
      job_type: job_type,
      payload: payload,
      status: status,
      attempts: attempts,
      max_attempts: max_attempts,
      timeout_seconds: timeout_seconds,
      run_at: run_at,
      started_at: started_at,
      completed_at: completed_at,
      last_error: last_error,
      created_at: created_at,
      updated_at: updated_at,
    )) ->
      db_helpers.execute(
        db,
        sql.insert_job(
          id: uuid.to_bit_array(id),
          job_type: job.job_type_to_string(job_type),
          payload: payload,
          status: job.status_to_string(status),
          attempts: attempts,
          max_attempts: max_attempts,
          timeout_seconds: timeout_seconds,
          run_at: run_at,
          started_at: started_at,
          completed_at: completed_at,
          last_error: last_error,
          created_at: created_at,
          updated_at: updated_at,
        ),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbInsertSnippet(
      id: id,
      user_id: user_id,
      language: language,
      title: title,
      visibility: visibility,
      stdin: stdin,
      run_command: run_command,
      files: files,
      created_at: created_at,
      updated_at: updated_at,
    ) ->
      db_helpers.execute(
        db,
        sql.insert_snippet(
          id: uuid.to_bit_array(id),
          user_id: uuid.to_bit_array(user_id),
          language: language.to_string(language),
          title: title,
          visibility: visibility,
          stdin: stdin,
          run_command: run_command,
          files: json.to_string(json.array(files, snippet.encode_file)),
          created_at: created_at,
          updated_at: updated_at,
        ),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbInsertLoginToken(
      id: id,
      user_id: user_id,
      token: token,
      created_at: created_at,
      used_at: used_at,
    ) ->
      db_helpers.execute(
        db,
        sql.insert_login_token(
          id: uuid.to_bit_array(id),
          user_id: uuid.to_bit_array(user_id),
          token: token,
          created_at: created_at,
          used_at: used_at,
        ),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbInsertSession(
      id: id,
      user_id: user_id,
      token: token,
      ip: ip,
      user_agent: user_agent,
      created_at: created_at,
    ) ->
      db_helpers.execute(
        db,
        sql.insert_session(
          id: uuid.to_bit_array(id),
          user_id: uuid.to_bit_array(user_id),
          token: token,
          ip: ip,
          user_agent: user_agent,
          created_at: created_at,
        ),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbUpdateLoginToken(
      user_id: user_id,
      token: token,
      created_at: created_at,
      used_at: used_at,
      id: id,
    ) ->
      db_helpers.execute(
        db,
        sql.update_login_token(
          user_id: uuid.to_bit_array(user_id),
          token: token,
          created_at: created_at,
          used_at: used_at,
          id: uuid.to_bit_array(id),
        ),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbInsertUserActivity(
      id: id,
      action: action,
      ip: ip,
      user_id: user_id,
      created_at: created_at,
    ) ->
      db_helpers.execute(
        db,
        sql.insert_user_activity(
          id: uuid.to_bit_array(id),
          action: api_action.to_db_string(action),
          ip: ip,
          user_id: option.map(user_id, uuid.to_bit_array),
          created_at: created_at,
        ),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbInsertLogEntry(
      id: id,
      created_at: created_at,
      action: action,
      duration_ns: duration_ns,
      ip: ip,
      user_agent: user_agent,
      error: error,
      data: data,
      effects: effects,
    ) ->
      db_helpers.execute(
        db,
        sql.insert_api_log(
          id: uuid.to_bit_array(id),
          created_at: created_at,
          action: action,
          duration_ns: duration_ns,
          ip: ip,
          user_agent: user_agent,
          error: error,
          data: data,
          effects: effects,
        ),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbMarkJobDone(id: id, completed_at: completed_at) ->
      db_helpers.execute(
        db,
        sql.mark_job_done(uuid.to_bit_array(id), option.Some(completed_at)),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbRescheduleJob(
      id: id,
      run_at: run_at,
      last_error: last_error,
      updated_at: updated_at,
    ) ->
      db_helpers.execute(
        db,
        sql.reschedule_job(
          uuid.to_bit_array(id),
          run_at,
          last_error,
          updated_at,
        ),
        to_error,
      )
      |> result.map(fn(_) { Nil })
  }
}

fn run_in_transaction(
  db: pog.Connection,
  commands: List(program.DbCommand),
) -> Result(Nil, program.DbTransactionError) {
  pog.transaction(db, fn(tx) { execute_commands(tx, commands) })
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(err) {
    program.DbTransactionError(string.inspect(err))
  })
}

fn execute_commands(
  db: pog.Connection,
  commands: List(program.DbCommand),
) -> Result(Nil, program.DbCommandError) {
  case commands {
    [] -> Ok(Nil)
    [command, ..rest] -> {
      use _ <- result.try(run_command(db, command))
      execute_commands(db, rest)
    }
  }
}

fn map_run_http_error(err: http_client.HttpError) -> program.RunRequestError {
  case err {
    http_client.BadStatus(status: _, body: body) ->
      case json.parse(body, run_error_message_decoder()) {
        Ok(message) -> program.PublicRunRequestError(message)
        Error(_) -> program.InternalRunRequestError(string.inspect(err))
      }
    _ -> program.InternalRunRequestError(string.inspect(err))
  }
}

fn run_error_message_decoder() -> decode.Decoder(String) {
  use message <- decode.field("message", decode.string)
  decode.success(message)
}
