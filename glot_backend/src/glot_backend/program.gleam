import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/sql
import glot_core/rate_limit
import glot_core/run

pub type DbQueryError {
  DbQueryError(message: String)
}

pub type DbCommandError {
  DbCommandError(message: String)
}

pub type DbTransactionError {
  DbTransactionError(message: String)
}

pub type RunRequestError {
  PublicRunRequestError(message: String)
  InternalRunRequestError(message: String)
}

pub type Error {
  DecodeError(List(decode.DecodeError))
  EmailInvalidError(String)
  TooManyRequestsError(count: Int, config: rate_limit.Config)
  QueryError(DbQueryError)
  CommandError(DbCommandError)
  TransactionError(DbTransactionError)
  RunError(RunRequestError)
}

pub type DbQuery(next) {
  DbGetUserByEmail(email: String, next: fn(List(sql.GetUserByEmail)) -> next)
  DbCountUserActivitiesByIpAndAction(
    created_at: Timestamp,
    ip: option.Option(String),
    action: sql.UserAction,
    next: fn(List(sql.CountUserActivitiesByIpAndAction)) -> next,
  )
}

pub type DbCommand {
  DbInsertUser(id: BitArray, email: String, created_at: Timestamp)
  DbInsertLoginToken(
    id: BitArray,
    user_id: BitArray,
    token: String,
    created_at: Timestamp,
    used_at: option.Option(Timestamp),
  )
  DbInsertUserActivity(
    id: BitArray,
    action: sql.UserAction,
    ip: option.Option(String),
    session_token: option.Option(String),
    created_at: Timestamp,
  )
}

pub type Handlers {
  Handlers(
    random_string: fn(Int) -> String,
    uuid_v7: fn() -> BitArray,
    log_info: fn(String) -> Nil,
    post_run_request: fn(context.Config, run.RunRequest) ->
      Result(run.RunResult, RunRequestError),
    get_user_by_email: fn(String) ->
      Result(List(sql.GetUserByEmail), DbQueryError),
    count_user_activities_by_ip_and_action: fn(
      Timestamp,
      option.Option(String),
      sql.UserAction,
    ) ->
      Result(List(sql.CountUserActivitiesByIpAndAction), DbQueryError),
    run_command: fn(DbCommand) -> Result(Nil, DbCommandError),
    run_in_transaction: fn(List(DbCommand)) -> Result(Nil, DbTransactionError),
  )
}

pub opaque type Program(a) {
  Done(a)
  Fail(Error)
  RandomString(Int, fn(String) -> Program(a))
  UuidV7(fn(BitArray) -> Program(a))
  LogInfo(String, Program(a))
  AttemptPostRunRequest(
    context.Config,
    run.RunRequest,
    fn(Result(run.RunResult, RunRequestError)) -> Program(a),
  )
  AttemptRunQuery(DbQuery(Program(a)), fn(DbQueryError) -> Program(a))
  AttemptRunCommand(DbCommand, fn(Result(Nil, DbCommandError)) -> Program(a))
  AttemptRunInTransaction(
    List(DbCommand),
    fn(Result(Nil, DbTransactionError)) -> Program(a),
  )
}

pub fn run(program: Program(a), handlers: Handlers) -> Result(a, Error) {
  case program {
    Done(value) -> Ok(value)
    Fail(error) -> Error(error)
    RandomString(length, next) ->
      run(next(handlers.random_string(length)), handlers)
    UuidV7(next) -> run(next(handlers.uuid_v7()), handlers)
    LogInfo(message, next) -> {
      let _ = handlers.log_info(message)
      run(next, handlers)
    }
    AttemptPostRunRequest(cfg, request, next) -> {
      let send_result = handlers.post_run_request(cfg, request)
      run(next(send_result), handlers)
    }
    AttemptRunQuery(query, on_error) -> {
      case run_db_query(query, handlers) {
        Ok(next_program) -> run(next_program, handlers)
        Error(query_error) -> run(on_error(query_error), handlers)
      }
    }
    AttemptRunCommand(command, next) -> {
      let command_result = handlers.run_command(command)
      run(next(command_result), handlers)
    }
    AttemptRunInTransaction(commands, next) -> {
      let transaction_result = handlers.run_in_transaction(commands)
      run(next(transaction_result), handlers)
    }
  }
}

pub fn succeed(value: a) -> Program(a) {
  Done(value)
}

pub fn fail(error: Error) -> Program(a) {
  Fail(error)
}

pub fn and_then(program: Program(a), f: fn(a) -> Program(b)) -> Program(b) {
  case program {
    Done(value) -> f(value)
    Fail(error) -> Fail(error)
    RandomString(length, next) ->
      RandomString(length, fn(value) { and_then(next(value), f) })
    UuidV7(next) -> UuidV7(fn(value) { and_then(next(value), f) })
    LogInfo(message, next) -> LogInfo(message, and_then(next, f))
    AttemptPostRunRequest(cfg, request, next) ->
      AttemptPostRunRequest(cfg, request, fn(value) { and_then(next(value), f) })
    AttemptRunQuery(query, on_error) ->
      AttemptRunQuery(map_db_query(query, fn(p) { and_then(p, f) }), fn(error) {
        and_then(on_error(error), f)
      })
    AttemptRunCommand(command, next) ->
      AttemptRunCommand(command, fn(value) { and_then(next(value), f) })
    AttemptRunInTransaction(commands, next) ->
      AttemptRunInTransaction(commands, fn(value) { and_then(next(value), f) })
  }
}

pub fn map(program: Program(a), f: fn(a) -> b) -> Program(b) {
  and_then(program, fn(value) { succeed(f(value)) })
}

pub fn decode_json(
  json_body: dynamic.Dynamic,
  decoder: decode.Decoder(a),
) -> Program(a) {
  decode.run(json_body, decoder)
  |> from_result(DecodeError)
}

pub fn random_string(length: Int) -> Program(String) {
  RandomString(length, Done)
}

pub fn uuid_v7() -> Program(BitArray) {
  UuidV7(Done)
}

pub fn log_info(message: String) -> Program(Nil) {
  LogInfo(message, Done(Nil))
}

pub fn attempt_post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> Program(Result(run.RunResult, RunRequestError)) {
  AttemptPostRunRequest(cfg, request, Done)
}

pub fn post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> Program(run.RunResult) {
  use run_result <- and_then(attempt_post_run_request(cfg, request))
  case run_result {
    Ok(value) -> Done(value)
    Error(error) -> Fail(RunError(error))
  }
}

pub fn attempt_run_query(query: DbQuery(a)) -> Program(Result(a, DbQueryError)) {
  AttemptRunQuery(map_db_query(query, fn(value) { Done(Ok(value)) }), fn(error) {
    Done(Error(error))
  })
}

pub fn run_query(query: DbQuery(a)) -> Program(a) {
  use query_result <- and_then(attempt_run_query(query))
  case query_result {
    Ok(value) -> Done(value)
    Error(error) -> Fail(QueryError(error))
  }
}

pub fn db_get_user_by_email(email: String) -> Program(List(sql.GetUserByEmail)) {
  run_query(DbGetUserByEmail(email:, next: identity))
}

pub fn db_count_user_activities_by_ip_and_action(
  created_at created_at: Timestamp,
  ip ip: option.Option(String),
  action action: sql.UserAction,
) -> Program(Int) {
  use rows <- and_then(
    run_query(DbCountUserActivitiesByIpAndAction(
      created_at: created_at,
      ip: ip,
      action: action,
      next: identity,
    )),
  )

  case list.first(rows) |> option.from_result() {
    option.Some(row) -> Done(row.count)
    option.None -> Done(0)
  }
}

pub fn enforce_ip_rate_limit(
  config config: rate_limit.Config,
  now now: Timestamp,
  ip ip: option.Option(String),
  action action: sql.UserAction,
) -> Program(Nil) {
  use count <- and_then(db_count_user_activities_by_ip_and_action(
    created_at: rate_limit.start_time(config, now),
    ip: ip,
    action: action,
  ))

  use id <- and_then(uuid_v7())
  use _ <- and_then(
    run_command(DbInsertUserActivity(
      id: id,
      action: action,
      ip: ip,
      session_token: option.None,
      created_at: now,
    )),
  )

  case count > config.max_requests {
    True -> Fail(TooManyRequestsError(count, config))
    False -> Done(Nil)
  }
}

pub fn attempt_run_command(
  command: DbCommand,
) -> Program(Result(Nil, DbCommandError)) {
  AttemptRunCommand(command, Done)
}

pub fn run_command(command: DbCommand) -> Program(Nil) {
  use command_result <- and_then(attempt_run_command(command))
  case command_result {
    Ok(_) -> Done(Nil)
    Error(error) -> Fail(CommandError(error))
  }
}

pub fn attempt_run_in_transaction(
  commands: List(DbCommand),
) -> Program(Result(Nil, DbTransactionError)) {
  AttemptRunInTransaction(commands, Done)
}

pub fn run_in_transaction(commands: List(DbCommand)) -> Program(Nil) {
  use transaction_result <- and_then(attempt_run_in_transaction(commands))
  case transaction_result {
    Ok(_) -> Done(Nil)
    Error(error) -> Fail(TransactionError(error))
  }
}

fn run_db_query(
  query: DbQuery(a),
  handlers: Handlers,
) -> Result(a, DbQueryError) {
  case query {
    DbGetUserByEmail(email:, next:) ->
      handlers.get_user_by_email(email) |> result.map(next)
    DbCountUserActivitiesByIpAndAction(created_at:, ip:, action:, next:) ->
      handlers.count_user_activities_by_ip_and_action(created_at, ip, action)
      |> result.map(next)
  }
}

fn map_db_query(query: DbQuery(a), f: fn(a) -> b) -> DbQuery(b) {
  case query {
    DbGetUserByEmail(email:, next:) ->
      DbGetUserByEmail(email: email, next: fn(value) { f(next(value)) })
    DbCountUserActivitiesByIpAndAction(created_at:, ip:, action:, next:) ->
      DbCountUserActivitiesByIpAndAction(
        created_at: created_at,
        ip: ip,
        action: action,
        next: fn(value) { f(next(value)) },
      )
  }
}

fn from_result(value: Result(a, e), map_error: fn(e) -> Error) -> Program(a) {
  case value {
    Ok(v) -> Done(v)
    Error(err) -> Fail(map_error(err))
  }
}

fn identity(value: a) -> a {
  value
}
