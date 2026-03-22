import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/email_message
import glot_backend/job
import glot_backend/log
import glot_backend/sql
import glot_core/rate_limit
import glot_core/run
import glot_core/user

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

pub type SendEmailError {
  PublicSendEmailError(message: String)
  InternalSendEmailError(message: String)
}

pub type Error {
  DecodeError(List(decode.DecodeError))
  EmailInvalidError(String)
  TooManyRequestsError(count: Int, config: rate_limit.Config)
  QueryError(DbQueryError)
  CommandError(DbCommandError)
  TransactionError(DbTransactionError)
  RunError(RunRequestError)
  SendEmailError(SendEmailError)
}

pub type DbQuery(next) {
  DbGetUserByEmail(email: String, next: fn(List(user.User)) -> next)
  DbGetNextJob(
    now: Timestamp,
    pending_status: job.Status,
    running_status: job.Status,
    next: fn(option.Option(job.Job)) -> next,
  )
  DbCountUserActivitiesByIpAndAction(
    created_at: Timestamp,
    ip: option.Option(String),
    action: sql.UserAction,
    next: fn(List(sql.CountUserActivitiesByIpAndAction)) -> next,
  )
}

pub type DbCommand {
  DbInsertUser(id: BitArray, email: String, created_at: Timestamp)
  DbInsertJob(job.Job)
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
  DbInsertLogEntry(
    id: BitArray,
    created_at: Timestamp,
    action: String,
    duration_ns: Int,
    user_agent: option.Option(String),
    error: option.Option(String),
    fields: String,
    effects: String,
  )
  DbMarkJobDone(id: BitArray, completed_at: Timestamp)
  DbRescheduleJob(
    id: BitArray,
    run_at: Timestamp,
    last_error: option.Option(String),
    updated_at: Timestamp,
  )
}

pub type Handlers {
  Handlers(
    random_string: fn(Int) -> String,
    system_time: fn() -> Timestamp,
    uuid_v7: fn() -> BitArray,
    post_run_request: fn(context.Config, run.RunRequest) ->
      Result(run.RunResult, RunRequestError),
    send_email: fn(email_message.EmailMessage) -> Result(Nil, SendEmailError),
    get_user_by_email: fn(String) ->
      Result(List(user.User), DbQueryError),
    get_next_job: fn(Timestamp, job.Status, job.Status) ->
      Result(option.Option(job.Job), DbQueryError),
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

pub type EffectName {
  RandomStringEffect
  SystemTimeEffect
  UuidV7Effect
  LogEffect
  PostRunRequestEffect
  SendEmailEffect
  RunQueryEffect(DbQueryName)
  RunCommandEffect(DbCommandName)
  RunInTransactionEffect(List(DbCommandName))
  CustomEffect(String)
}

pub type DbQueryName {
  DbGetUserByEmailQuery
  DbGetNextJobQuery
  DbCountUserActivitiesByIpAndActionQuery
}

pub type DbCommandName {
  DbInsertUserCommand
  DbInsertJobCommand
  DbInsertLoginTokenCommand
  DbInsertUserActivityCommand
  DbInsertLogEntryCommand
  DbMarkJobDoneCommand
  DbRescheduleJobCommand
}

pub type EffectTiming =
  #(EffectName, Int)

pub type State {
  State(effect_timings: List(EffectTiming), log_fields: log.Fields)
}

pub opaque type Program(a) {
  Done(a)
  Fail(Error)
  MeasureEffectDuration(EffectName, Int, Program(a))
  RandomString(Int, fn(String) -> Program(a))
  SystemTime(fn(Timestamp) -> Program(a))
  UuidV7(fn(BitArray) -> Program(a))
  Log(String, log.Value, Program(a))
  AttemptPostRunRequest(
    context.Config,
    run.RunRequest,
    fn(Result(run.RunResult, RunRequestError)) -> Program(a),
  )
  AttemptSendEmail(
    email_message.EmailMessage,
    fn(Result(Nil, SendEmailError)) -> Program(a),
  )
  AttemptRunQuery(DbQuery(Program(a)), fn(DbQueryError) -> Program(a))
  AttemptRunCommand(DbCommand, fn(Result(Nil, DbCommandError)) -> Program(a))
  AttemptRunInTransaction(
    List(DbCommand),
    fn(Result(Nil, DbTransactionError)) -> Program(a),
  )
}

pub fn run(
  program: Program(a),
  handlers: Handlers,
) -> #(Result(a, Error), State) {
  let #(result, state) =
    run_with_state(
      program,
      handlers,
      State(effect_timings: [], log_fields: log.new()),
    )

  #(result, State(..state, effect_timings: list.reverse(state.effect_timings)))
}

fn run_with_state(
  program: Program(a),
  handlers: Handlers,
  state: State,
) -> #(Result(a, Error), State) {
  case program {
    Done(value) -> #(Ok(value), state)
    Fail(error) -> #(Error(error), state)
    MeasureEffectDuration(name, duration_ns, next) ->
      run_with_state(
        next,
        handlers,
        add_effect_timings(state, name, duration_ns),
      )
    RandomString(length, next) -> {
      let started_at = now_ns()
      let value = handlers.random_string(length)
      run_with_state(
        next(value),
        handlers,
        measure_effect(state, RandomStringEffect, started_at),
      )
    }
    SystemTime(next) -> {
      let started_at = now_ns()
      let value = handlers.system_time()
      run_with_state(
        next(value),
        handlers,
        measure_effect(state, SystemTimeEffect, started_at),
      )
    }
    UuidV7(next) -> {
      let started_at = now_ns()
      let value = handlers.uuid_v7()
      run_with_state(
        next(value),
        handlers,
        measure_effect(state, UuidV7Effect, started_at),
      )
    }
    Log(key, value, next) -> {
      let started_at = now_ns()
      let state = add_log_field(state, key, value)
      run_with_state(
        next,
        handlers,
        measure_effect(state, LogEffect, started_at),
      )
    }
    AttemptPostRunRequest(cfg, request, next) -> {
      let started_at = now_ns()
      let send_result = handlers.post_run_request(cfg, request)
      run_with_state(
        next(send_result),
        handlers,
        measure_effect(state, PostRunRequestEffect, started_at),
      )
    }
    AttemptSendEmail(message, next) -> {
      let started_at = now_ns()
      let send_result = handlers.send_email(message)
      run_with_state(
        next(send_result),
        handlers,
        measure_effect(state, SendEmailEffect, started_at),
      )
    }
    AttemptRunQuery(query, on_error) -> {
      let started_at = now_ns()
      let next_state =
        measure_effect(state, RunQueryEffect(db_query_name(query)), started_at)
      case run_db_query(query, handlers) {
        Ok(next_program) -> run_with_state(next_program, handlers, next_state)
        Error(query_error) ->
          run_with_state(on_error(query_error), handlers, next_state)
      }
    }
    AttemptRunCommand(command, next) -> {
      let started_at = now_ns()
      let command_result = handlers.run_command(command)
      run_with_state(
        next(command_result),
        handlers,
        measure_effect(
          state,
          RunCommandEffect(db_command_name(command)),
          started_at,
        ),
      )
    }
    AttemptRunInTransaction(commands, next) -> {
      let started_at = now_ns()
      let transaction_result = handlers.run_in_transaction(commands)
      run_with_state(
        next(transaction_result),
        handlers,
        measure_effect(
          state,
          RunInTransactionEffect(list.map(commands, db_command_name)),
          started_at,
        ),
      )
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
    MeasureEffectDuration(name, duration_ms, next) ->
      MeasureEffectDuration(name, duration_ms, and_then(next, f))
    RandomString(length, next) ->
      RandomString(length, fn(value) { and_then(next(value), f) })
    SystemTime(next) -> SystemTime(fn(value) { and_then(next(value), f) })
    UuidV7(next) -> UuidV7(fn(value) { and_then(next(value), f) })
    Log(key, value, next) -> Log(key, value, and_then(next, f))
    AttemptPostRunRequest(cfg, request, next) ->
      AttemptPostRunRequest(cfg, request, fn(value) { and_then(next(value), f) })
    AttemptSendEmail(message, next) ->
      AttemptSendEmail(message, fn(value) { and_then(next(value), f) })
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

pub fn system_time() -> Program(Timestamp) {
  SystemTime(Done)
}

pub fn measure_effect_duration(
  effect_name: EffectName,
  duration_ms: Int,
) -> Program(Nil) {
  MeasureEffectDuration(effect_name, duration_ms, Done(Nil))
}

pub fn uuid_v7() -> Program(BitArray) {
  UuidV7(Done)
}

pub fn log(key: String, value: log.Value) -> Program(Nil) {
  Log(key, value, Done(Nil))
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

pub fn attempt_send_email(
  message: email_message.EmailMessage,
) -> Program(Result(Nil, SendEmailError)) {
  AttemptSendEmail(message, Done)
}

pub fn send_email(message: email_message.EmailMessage) -> Program(Nil) {
  use send_result <- and_then(attempt_send_email(message))
  case send_result {
    Ok(_) -> Done(Nil)
    Error(error) -> Fail(SendEmailError(error))
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

pub fn db_get_user_by_email(email: String) -> Program(List(user.User)) {
  run_query(DbGetUserByEmail(email:, next: identity))
}

pub fn db_get_next_job(
  now: Timestamp,
  pending_status: job.Status,
  running_status: job.Status,
) -> Program(option.Option(job.Job)) {
  run_query(DbGetNextJob(now:, pending_status:, running_status:, next: identity))
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
    DbGetNextJob(now:, pending_status:, running_status:, next:) ->
      handlers.get_next_job(now, pending_status, running_status)
      |> result.map(next)
    DbCountUserActivitiesByIpAndAction(created_at:, ip:, action:, next:) ->
      handlers.count_user_activities_by_ip_and_action(created_at, ip, action)
      |> result.map(next)
  }
}

fn map_db_query(query: DbQuery(a), f: fn(a) -> b) -> DbQuery(b) {
  case query {
    DbGetUserByEmail(email:, next:) ->
      DbGetUserByEmail(email: email, next: fn(value) { f(next(value)) })
    DbGetNextJob(now:, pending_status:, running_status:, next:) ->
      DbGetNextJob(
        now: now,
        pending_status: pending_status,
        running_status: running_status,
        next: fn(value) { f(next(value)) },
      )
    DbCountUserActivitiesByIpAndAction(created_at:, ip:, action:, next:) ->
      DbCountUserActivitiesByIpAndAction(
        created_at: created_at,
        ip: ip,
        action: action,
        next: fn(value) { f(next(value)) },
      )
  }
}

fn db_query_name(query: DbQuery(a)) -> DbQueryName {
  case query {
    DbGetUserByEmail(_, _) -> DbGetUserByEmailQuery
    DbGetNextJob(_, _, _, _) -> DbGetNextJobQuery
    DbCountUserActivitiesByIpAndAction(_, _, _, _) ->
      DbCountUserActivitiesByIpAndActionQuery
  }
}

fn db_command_name(command: DbCommand) -> DbCommandName {
  case command {
    DbInsertUser(_, _, _) -> DbInsertUserCommand
    DbInsertJob(_) -> DbInsertJobCommand
    DbInsertLoginToken(_, _, _, _, _) -> DbInsertLoginTokenCommand
    DbInsertUserActivity(_, _, _, _, _) -> DbInsertUserActivityCommand
    DbInsertLogEntry(_, _, _, _, _, _, _, _) -> DbInsertLogEntryCommand
    DbMarkJobDone(_, _) -> DbMarkJobDoneCommand
    DbRescheduleJob(_, _, _, _) -> DbRescheduleJobCommand
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

fn measure_effect(
  state: State,
  effect_name: EffectName,
  started_at_ns: Int,
) -> State {
  let elapsed_ns = now_ns() - started_at_ns
  let safe_elapsed_ns = int.max(elapsed_ns, 0)
  add_effect_timings(state, effect_name, safe_elapsed_ns)
}

fn add_effect_timings(
  state: State,
  effect_name: EffectName,
  duration_ns: Int,
) -> State {
  let State(effect_timings:, log_fields:) = state
  State(
    effect_timings: [#(effect_name, duration_ns), ..effect_timings],
    log_fields: log_fields,
  )
}

fn add_log_field(state: State, key: String, value: log.Value) -> State {
  let State(effect_timings:, log_fields:) = state
  State(
    effect_timings: effect_timings,
    log_fields: dict.insert(log_fields, key, value),
  )
}

fn now_ns() -> Int {
  let #(seconds, nanoseconds) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds
  seconds * 1_000_000_000 + nanoseconds
}
