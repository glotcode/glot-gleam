import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/function
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/context
import glot_backend/email_message
import glot_backend/job
import glot_backend/log
import glot_core/auth
import glot_core/email
import glot_core/rate_limit.{type RateLimit}
import glot_core/run
import glot_core/snippet
import glot_core/user
import youid/uuid.{type Uuid}

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

pub type LoginError {
  InvalidTokenError
  TokenUsedError
  TokenExpiredError
}

pub type SendEmailError {
  PublicSendEmailError(message: String)
  InternalSendEmailError(message: String)
}

pub type SessionError {
  MissingSessionTokenError
  SessionNotFoundError
  SessionExpiredError
}

pub type Error {
  DecodeError(List(decode.DecodeError))
  EmailInvalidError(String)
  TooManyRequestsError(count: Int, rate_limit: RateLimit)
  QueryError(DbQueryError)
  CommandError(DbCommandError)
  TransactionError(DbTransactionError)
  RunError(RunRequestError)
  LoginError(LoginError)
  SendEmailError(SendEmailError)
  SessionError(SessionError)
}

pub type DbQuery(next) {
  DbGetUserByEmail(
    email: email.Email,
    next: fn(option.Option(user.User)) -> next,
  )
  DbListLoginTokensByUser(
    user_id: Uuid,
    limit: Int,
    next: fn(List(auth.LoginToken)) -> next,
  )
  DbGetSessionByToken(
    token: String,
    next: fn(option.Option(auth.Session)) -> next,
  )
  DbGetNextJob(
    now: Timestamp,
    pending_status: job.Status,
    running_status: job.Status,
    next: fn(option.Option(job.Job)) -> next,
  )
  DbCountUserActivitiesByIp(
    windows: List(rate_limit.Window),
    ip: option.Option(String),
    action: ApiAction,
    next: fn(List(rate_limit.WindowCount)) -> next,
  )
  DbCountUserActivitiesByUser(
    windows: List(rate_limit.Window),
    user_id: option.Option(Uuid),
    action: ApiAction,
    next: fn(List(rate_limit.WindowCount)) -> next,
  )
}

pub type DbCommand {
  DbInsertUser(id: Uuid, email: String, created_at: Timestamp)
  DbInsertJob(job.Job)
  DbInsertSnippet(
    id: Uuid,
    user_id: Uuid,
    snippet: snippet.Snippet,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
  DbInsertSession(
    id: Uuid,
    user_id: Uuid,
    token: String,
    ip: option.Option(String),
    user_agent: option.Option(String),
    created_at: Timestamp,
  )
  DbInsertLoginToken(
    id: Uuid,
    user_id: Uuid,
    token: String,
    created_at: Timestamp,
    used_at: option.Option(Timestamp),
  )
  DbUpdateLoginToken(
    user_id: Uuid,
    token: String,
    created_at: Timestamp,
    used_at: option.Option(Timestamp),
    id: Uuid,
  )
  DbInsertUserActivity(
    id: Uuid,
    action: ApiAction,
    ip: option.Option(String),
    user_id: option.Option(Uuid),
    created_at: Timestamp,
  )
  DbInsertLogEntry(
    id: Uuid,
    created_at: Timestamp,
    action: String,
    duration_ns: Int,
    ip: option.Option(String),
    user_agent: option.Option(String),
    error: option.Option(String),
    data: String,
    effects: String,
  )
  DbMarkJobDone(id: Uuid, completed_at: Timestamp)
  DbRescheduleJob(
    id: Uuid,
    run_at: Timestamp,
    last_error: option.Option(String),
    updated_at: Timestamp,
  )
}

pub type Handlers {
  Handlers(
    new_token: fn(Int) -> String,
    system_time: fn() -> Timestamp,
    uuid_v7: fn() -> Uuid,
    post_run_request: fn(context.Config, run.RunRequest) ->
      Result(run.RunResult, RunRequestError),
    send_email: fn(email_message.EmailMessage) -> Result(Nil, SendEmailError),
    get_user_by_email: fn(email.Email) ->
      Result(option.Option(user.User), DbQueryError),
    list_login_tokens_by_user: fn(Uuid, Int) ->
      Result(List(auth.LoginToken), DbQueryError),
    get_session_by_token: fn(String) ->
      Result(option.Option(auth.Session), DbQueryError),
    get_next_job: fn(Timestamp, job.Status, job.Status) ->
      Result(option.Option(job.Job), DbQueryError),
    count_user_activities_by_ip: fn(
      List(rate_limit.Window),
      option.Option(String),
      ApiAction,
    ) ->
      Result(List(rate_limit.WindowCount), DbQueryError),
    count_user_activities_by_user: fn(
      List(rate_limit.Window),
      option.Option(Uuid),
      ApiAction,
    ) ->
      Result(List(rate_limit.WindowCount), DbQueryError),
    run_command: fn(DbCommand) -> Result(Nil, DbCommandError),
    run_in_transaction: fn(List(DbCommand)) -> Result(Nil, DbTransactionError),
  )
}

pub type EffectName {
  NewTokenEffect
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
  DbListLoginTokensByUserQuery
  DbGetSessionByTokenQuery
  DbGetNextJobQuery
  DbCountUserActivitiesByIpQuery
  DbCountUserActivitiesByUserQuery
}

pub type DbCommandName {
  DbInsertUserCommand
  DbInsertJobCommand
  DbInsertSnippetCommand
  DbInsertSessionCommand
  DbInsertLoginTokenCommand
  DbUpdateLoginTokenCommand
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
  NewToken(Int, fn(String) -> Program(a))
  SystemTime(fn(Timestamp) -> Program(a))
  UuidV7(fn(Uuid) -> Program(a))
  Log(log.Fields, Program(a))
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
    NewToken(length, next) -> {
      let started_at = now_ns()
      let value = handlers.new_token(length)
      run_with_state(
        next(value),
        handlers,
        measure_effect(state, NewTokenEffect, started_at),
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
    Log(fields, next) -> {
      let started_at = now_ns()
      let state = add_log_fields(state, fields)
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
    NewToken(length, next) ->
      NewToken(length, fn(value) { and_then(next(value), f) })
    SystemTime(next) -> SystemTime(fn(value) { and_then(next(value), f) })
    UuidV7(next) -> UuidV7(fn(value) { and_then(next(value), f) })
    Log(fields, next) -> Log(fields, and_then(next, f))
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

pub fn new_token(length: Int) -> Program(String) {
  NewToken(length, Done)
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

pub fn uuid_v7() -> Program(Uuid) {
  UuidV7(Done)
}

pub fn log(fields: log.Fields) -> Program(Nil) {
  Log(fields, Done(Nil))
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

pub fn db_get_user_by_email(
  email email: email.Email,
) -> Program(option.Option(user.User)) {
  run_query(DbGetUserByEmail(email:, next: function.identity))
}

pub fn db_list_login_tokens_by_user(
  user_id user_id: Uuid,
  limit limit: Int,
) -> Program(List(auth.LoginToken)) {
  run_query(DbListLoginTokensByUser(
    user_id: user_id,
    limit: limit,
    next: function.identity,
  ))
}

pub fn db_get_session_by_token(
  token token: String,
) -> Program(option.Option(auth.Session)) {
  run_query(DbGetSessionByToken(token: token, next: function.identity))
}

pub fn db_get_next_job(
  now: Timestamp,
  pending_status: job.Status,
  running_status: job.Status,
) -> Program(option.Option(job.Job)) {
  run_query(DbGetNextJob(
    now: now,
    pending_status: pending_status,
    running_status: running_status,
    next: function.identity,
  ))
}

pub fn db_count_user_activities_by_ip(
  windows windows: List(rate_limit.Window),
  ip ip: option.Option(String),
  action action: ApiAction,
) -> Program(List(rate_limit.WindowCount)) {
  run_query(DbCountUserActivitiesByIp(
    windows: windows,
    ip: ip,
    action: action,
    next: function.identity,
  ))
}

pub fn db_count_user_activities_by_user(
  windows windows: List(rate_limit.Window),
  user_id user_id: option.Option(Uuid),
  action action: ApiAction,
) -> Program(List(rate_limit.WindowCount)) {
  run_query(DbCountUserActivitiesByUser(
    windows: windows,
    user_id: user_id,
    action: action,
    next: function.identity,
  ))
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
    DbListLoginTokensByUser(user_id:, limit:, next:) ->
      handlers.list_login_tokens_by_user(user_id, limit) |> result.map(next)
    DbGetSessionByToken(token:, next:) ->
      handlers.get_session_by_token(token) |> result.map(next)
    DbGetNextJob(now:, pending_status:, running_status:, next:) ->
      handlers.get_next_job(now, pending_status, running_status)
      |> result.map(next)
    DbCountUserActivitiesByIp(windows:, ip:, action:, next:) ->
      handlers.count_user_activities_by_ip(windows, ip, action)
      |> result.map(next)
    DbCountUserActivitiesByUser(windows:, user_id:, action:, next:) ->
      handlers.count_user_activities_by_user(windows, user_id, action)
      |> result.map(next)
  }
}

fn map_db_query(query: DbQuery(a), f: fn(a) -> b) -> DbQuery(b) {
  case query {
    DbGetUserByEmail(email:, next:) ->
      DbGetUserByEmail(email: email, next: fn(value) { f(next(value)) })
    DbListLoginTokensByUser(user_id:, limit:, next:) ->
      DbListLoginTokensByUser(user_id: user_id, limit: limit, next: fn(value) {
        f(next(value))
      })
    DbGetSessionByToken(token:, next:) ->
      DbGetSessionByToken(token: token, next: fn(value) { f(next(value)) })
    DbGetNextJob(now:, pending_status:, running_status:, next:) ->
      DbGetNextJob(
        now: now,
        pending_status: pending_status,
        running_status: running_status,
        next: fn(value) { f(next(value)) },
      )
    DbCountUserActivitiesByIp(windows:, ip:, action:, next:) ->
      DbCountUserActivitiesByIp(
        windows: windows,
        ip: ip,
        action: action,
        next: fn(value) { f(next(value)) },
      )
    DbCountUserActivitiesByUser(windows:, user_id:, action:, next:) ->
      DbCountUserActivitiesByUser(
        windows: windows,
        user_id: user_id,
        action: action,
        next: fn(value) { f(next(value)) },
      )
  }
}

fn db_query_name(query: DbQuery(a)) -> DbQueryName {
  case query {
    DbGetUserByEmail(_, _) -> DbGetUserByEmailQuery
    DbListLoginTokensByUser(_, _, _) -> DbListLoginTokensByUserQuery
    DbGetSessionByToken(_, _) -> DbGetSessionByTokenQuery
    DbGetNextJob(_, _, _, _) -> DbGetNextJobQuery
    DbCountUserActivitiesByIp(_, _, _, _) -> DbCountUserActivitiesByIpQuery
    DbCountUserActivitiesByUser(_, _, _, _) -> DbCountUserActivitiesByUserQuery
  }
}

fn db_command_name(command: DbCommand) -> DbCommandName {
  case command {
    DbInsertUser(_, _, _) -> DbInsertUserCommand
    DbInsertJob(_) -> DbInsertJobCommand
    DbInsertSnippet(_, _, _, _, _) -> DbInsertSnippetCommand
    DbInsertSession(_, _, _, _, _, _) -> DbInsertSessionCommand
    DbInsertLoginToken(_, _, _, _, _) -> DbInsertLoginTokenCommand
    DbUpdateLoginToken(_, _, _, _, _) -> DbUpdateLoginTokenCommand
    DbInsertUserActivity(_, _, _, _, _) -> DbInsertUserActivityCommand
    DbInsertLogEntry(_, _, _, _, _, _, _, _, _) -> DbInsertLogEntryCommand
    DbMarkJobDone(_, _) -> DbMarkJobDoneCommand
    DbRescheduleJob(_, _, _, _) -> DbRescheduleJobCommand
  }
}

pub fn from_result(value: Result(a, e), map_error: fn(e) -> Error) -> Program(a) {
  case value {
    Ok(v) -> Done(v)
    Error(err) -> Fail(map_error(err))
  }
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

fn add_log_fields(state: State, fields: log.Fields) -> State {
  let State(effect_timings:, log_fields:) = state
  State(
    effect_timings: effect_timings,
    log_fields: dict.merge(log_fields, fields),
  )
}

fn now_ns() -> Int {
  let #(seconds, nanoseconds) =
    timestamp.system_time()
    |> timestamp.to_unix_seconds_and_nanoseconds
  seconds * 1_000_000_000 + nanoseconds
}
