import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/db_helpers
import glot_backend/http_client
import glot_backend/program
import glot_backend/sql
import glot_core/run
import glot_core/uuid_helpers
import pog
import wisp

pub fn from_context(ctx: context.Context) -> program.Handlers {
  program.Handlers(
    random_string: wisp.random_string,
    system_time: timestamp.system_time,
    uuid_v7: fn() { uuid_helpers.v7_bit_array(ctx.timestamp) },
    log_info: wisp.log_info,
    post_run_request: post_run_request,
    get_user_by_email: fn(email) { get_user_by_email(ctx, email) },
    count_user_activities_by_ip_and_action: fn(created_at, ip, action) {
      count_user_activities_by_ip_and_action(ctx, created_at, ip, action)
    },
    run_command: fn(command) { run_command(ctx.db, command) },
    run_in_transaction: fn(commands) { run_in_transaction(ctx.db, commands) },
  )
}

fn post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> Result(run.RunResult, program.RunRequestError) {
  http_client.post_json(
    url: cfg.docker_run_base_url <> "/run",
    body: run.encode_run_request(request),
    headers: dict.from_list([#("X-Access-Token", cfg.docker_run_access_token)]),
    decoder: run.run_result_decoder(),
  )
  |> result.map_error(map_run_http_error)
}

fn get_user_by_email(
  ctx: context.Context,
  email: String,
) -> Result(List(sql.GetUserByEmail), program.DbQueryError) {
  db_helpers.query(ctx.db, sql.get_user_by_email(email), fn(err) {
    program.DbQueryError(string.inspect(err))
  })
  |> result.map(fn(returned) { returned.rows })
}

fn count_user_activities_by_ip_and_action(
  ctx: context.Context,
  created_at: Timestamp,
  ip: option.Option(String),
  action: sql.UserAction,
) -> Result(List(sql.CountUserActivitiesByIpAndAction), program.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.count_user_activities_by_ip_and_action(
      created_at: created_at,
      ip: ip,
      action: action,
    ),
    fn(err) { program.DbQueryError(string.inspect(err)) },
  )
  |> result.map(fn(returned) { returned.rows })
}

fn run_command(
  db: pog.Connection,
  command: program.DbCommand,
) -> Result(Nil, program.DbCommandError) {
  let to_error = fn(err) { program.DbCommandError(string.inspect(err)) }

  case command {
    program.DbInsertUser(id:, email:, created_at:) ->
      db_helpers.execute(db, sql.insert_user(id, email, created_at), to_error)
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
          id: id,
          user_id: user_id,
          token: token,
          created_at: created_at,
          used_at: used_at,
        ),
        to_error,
      )
      |> result.map(fn(_) { Nil })
    program.DbInsertUserActivity(
      id: id,
      action: action,
      ip: ip,
      session_token: session_token,
      created_at: created_at,
    ) ->
      db_helpers.execute(
        db,
        sql.insert_user_activity(
          id: id,
          action: action,
          ip: ip,
          session_token: session_token,
          created_at: created_at,
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
