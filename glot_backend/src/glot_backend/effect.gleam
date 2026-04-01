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
import glot_backend/erlang
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
  DbCountUserActionsByIp(
    windows: List(rate_limit.Window),
    ip: option.Option(String),
    action: ApiAction,
    next: fn(List(rate_limit.WindowCount)) -> next,
  )
  DbCountUserActionsByUser(
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
  DbInsertUserAction(
    id: Uuid,
    request_id: Uuid,
    action: ApiAction,
    ip: option.Option(String),
    user_id: option.Option(Uuid),
    created_at: Timestamp,
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
    count_user_actions_by_ip: fn(
      List(rate_limit.Window),
      option.Option(String),
      ApiAction,
    ) ->
      Result(List(rate_limit.WindowCount), DbQueryError),
    count_user_actions_by_user: fn(
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
  DbCountUserActionsByIpQuery
  DbCountUserActionsByUserQuery
}

pub type DbCommandName {
  DbInsertUserCommand
  DbInsertJobCommand
  DbInsertSnippetCommand
  DbInsertSessionCommand
  DbInsertLoginTokenCommand
  DbUpdateLoginTokenCommand
  DbInsertUserActionCommand
  DbMarkJobDoneCommand
  DbRescheduleJobCommand
}

pub type EffectTiming =
  #(EffectName, Int)

pub type State {
  State(
    effect_timings: List(EffectTiming),
    info_fields: log.Fields,
    warning_fields: log.Fields,
  )
}

fn new_state() -> State {
  State(effect_timings: [], info_fields: log.new(), warning_fields: log.new())
}

pub type Free(a) {
  Pure(a)
  Fail(Error)
  Impure(Effect(Free(a)))
}

pub type Effect(next) {
  MeasureEffectDuration(EffectName, Int, next)
  NewToken(Int, fn(String) -> next)
  SystemTime(fn(Timestamp) -> next)
  UuidV7(fn(Uuid) -> next)
  Log(log.Level, log.Fields, next)
  AttemptPostRunRequest(
    context.Config,
    run.RunRequest,
    fn(Result(run.RunResult, RunRequestError)) -> next,
  )
  AttemptSendEmail(
    email_message.EmailMessage,
    fn(Result(Nil, SendEmailError)) -> next,
  )
  AttemptRunQuery(DbQuery(next), fn(DbQueryError) -> next)
  AttemptRunCommand(DbCommand, fn(Result(Nil, DbCommandError)) -> next)
  AttemptRunInTransaction(
    List(DbCommand),
    fn(Result(Nil, DbTransactionError)) -> next,
  )
}

pub fn run(
  effect: Free(a),
  handlers: Handlers,
) -> #(Result(a, Error), State) {
  let #(result, state) = run_with_state(effect, handlers, new_state())
  #(result, State(..state, effect_timings: list.reverse(state.effect_timings)))
}

fn run_with_state(
  effect: Free(a),
  handlers: Handlers,
  state: State,
) -> #(Result(a, Error), State) {
  case effect {
    Pure(value) -> #(Ok(value), state)
    Fail(error) -> #(Error(error), state)
    Impure(effect) ->
      case effect {
        MeasureEffectDuration(name, duration_ns, next) ->
          run_with_state(
            next,
            handlers,
            add_effect_timings(state, name, duration_ns),
          )
        NewToken(length, next) -> {
          let started_at = erlang.perf_counter_ns()
          let value = handlers.new_token(length)
          run_with_state(
            next(value),
            handlers,
            measure_effect(state, NewTokenEffect, started_at),
          )
        }
        SystemTime(next) -> {
          let started_at = erlang.perf_counter_ns()
          let value = handlers.system_time()
          run_with_state(
            next(value),
            handlers,
            measure_effect(state, SystemTimeEffect, started_at),
          )
        }
        UuidV7(next) -> {
          let started_at = erlang.perf_counter_ns()
          let value = handlers.uuid_v7()
          run_with_state(
            next(value),
            handlers,
            measure_effect(state, UuidV7Effect, started_at),
          )
        }
        Log(level, fields, next) -> {
          let started_at = erlang.perf_counter_ns()
          let state = case level {
            log.Info -> add_info_fields(state, fields)
            log.Warn -> add_warning_fields(state, fields)
          }
          run_with_state(
            next,
            handlers,
            measure_effect(state, LogEffect, started_at),
          )
        }
        AttemptPostRunRequest(cfg, request, next) -> {
          let started_at = erlang.perf_counter_ns()
          let send_result = handlers.post_run_request(cfg, request)
          run_with_state(
            next(send_result),
            handlers,
            measure_effect(state, PostRunRequestEffect, started_at),
          )
        }
        AttemptSendEmail(message, next) -> {
          let started_at = erlang.perf_counter_ns()
          let send_result = handlers.send_email(message)
          run_with_state(
            next(send_result),
            handlers,
            measure_effect(state, SendEmailEffect, started_at),
          )
        }
        AttemptRunQuery(query, on_error) -> {
          let started_at = erlang.perf_counter_ns()
          case run_db_query(query, handlers) {
            Ok(next_effect) ->
              run_with_state(
                next_effect,
                handlers,
                measure_effect(
                  state,
                  RunQueryEffect(db_query_name(query)),
                  started_at,
                ),
              )
            Error(query_error) ->
              run_with_state(
                on_error(query_error),
                handlers,
                measure_effect(
                  state,
                  RunQueryEffect(db_query_name(query)),
                  started_at,
                ),
              )
          }
        }
        AttemptRunCommand(command, next) -> {
          let started_at = erlang.perf_counter_ns()
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
          let started_at = erlang.perf_counter_ns()
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
}

pub fn succeed(value: a) -> Free(a) {
  Pure(value)
}

pub fn fail(error: Error) -> Free(a) {
  Fail(error)
}

pub fn and_then(effect: Free(a), f: fn(a) -> Free(b)) -> Free(b) {
  case effect {
    Pure(value) -> f(value)
    Fail(error) -> Fail(error)
    Impure(next) -> Impure(map_effect(next, fn(value) { and_then(value, f) }))
  }
}

pub fn map(effect: Free(a), f: fn(a) -> b) -> Free(b) {
  and_then(effect, fn(value) { succeed(f(value)) })
}

pub fn decode_json(
  json_body: dynamic.Dynamic,
  decoder: decode.Decoder(a),
) -> Free(a) {
  decode.run(json_body, decoder)
  |> result.map_error(DecodeError)
  |> from_result
}

pub fn new_token(length: Int) -> Free(String) {
  Impure(NewToken(length, Pure))
}

pub fn system_time() -> Free(Timestamp) {
  Impure(SystemTime(Pure))
}

pub fn measure_effect_duration(
  effect_name: EffectName,
  duration_ms: Int,
) -> Free(Nil) {
  Impure(MeasureEffectDuration(effect_name, duration_ms, Pure(Nil)))
}

pub fn uuid_v7() -> Free(Uuid) {
  Impure(UuidV7(Pure))
}

pub fn info(fields: log.Fields) -> Free(Nil) {
  Impure(Log(log.Info, fields, Pure(Nil)))
}

pub fn warn(fields: log.Fields) -> Free(Nil) {
  Impure(Log(log.Warn, fields, Pure(Nil)))
}

pub fn when(condition: Bool, if_true: Free(Nil)) -> Free(Nil) {
  case condition {
    True -> if_true
    False -> Pure(Nil)
  }
}

pub fn attempt_post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> Free(Result(run.RunResult, RunRequestError)) {
  Impure(AttemptPostRunRequest(cfg, request, Pure))
}

pub fn post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> Free(run.RunResult) {
  use run_result <- and_then(attempt_post_run_request(cfg, request))
  case run_result {
    Ok(value) -> Pure(value)
    Error(error) -> Fail(RunError(error))
  }
}

pub fn attempt_send_email(
  message: email_message.EmailMessage,
) -> Free(Result(Nil, SendEmailError)) {
  Impure(AttemptSendEmail(message, Pure))
}

pub fn send_email(message: email_message.EmailMessage) -> Free(Nil) {
  use send_result <- and_then(attempt_send_email(message))
  case send_result {
    Ok(_) -> Pure(Nil)
    Error(error) -> Fail(SendEmailError(error))
  }
}

pub fn attempt_run_query(query: DbQuery(a)) -> Free(Result(a, DbQueryError)) {
  Impure(AttemptRunQuery(map_db_query(query, fn(value) { Pure(Ok(value)) }), fn(
    error,
  ) {
    Pure(Error(error))
  }))
}

pub fn run_query(query: DbQuery(a)) -> Free(a) {
  use query_result <- and_then(attempt_run_query(query))
  case query_result {
    Ok(value) -> Pure(value)
    Error(error) -> Fail(QueryError(error))
  }
}

pub fn db_get_user_by_email(
  email email: email.Email,
) -> Free(option.Option(user.User)) {
  run_query(DbGetUserByEmail(email:, next: function.identity))
}

pub fn db_list_login_tokens_by_user(
  user_id user_id: Uuid,
  limit limit: Int,
) -> Free(List(auth.LoginToken)) {
  run_query(DbListLoginTokensByUser(
    user_id: user_id,
    limit: limit,
    next: function.identity,
  ))
}

pub fn db_get_session_by_token(
  token token: String,
) -> Free(option.Option(auth.Session)) {
  run_query(DbGetSessionByToken(token: token, next: function.identity))
}

pub fn db_get_next_job(
  now: Timestamp,
  pending_status: job.Status,
  running_status: job.Status,
) -> Free(option.Option(job.Job)) {
  run_query(DbGetNextJob(
    now: now,
    pending_status: pending_status,
    running_status: running_status,
    next: function.identity,
  ))
}

pub fn db_count_user_actions_by_ip(
  windows windows: List(rate_limit.Window),
  ip ip: option.Option(String),
  action action: ApiAction,
) -> Free(List(rate_limit.WindowCount)) {
  run_query(DbCountUserActionsByIp(
    windows: windows,
    ip: ip,
    action: action,
    next: function.identity,
  ))
}

pub fn db_count_user_actions_by_user(
  windows windows: List(rate_limit.Window),
  user_id user_id: option.Option(Uuid),
  action action: ApiAction,
) -> Free(List(rate_limit.WindowCount)) {
  run_query(DbCountUserActionsByUser(
    windows: windows,
    user_id: user_id,
    action: action,
    next: function.identity,
  ))
}

pub fn attempt_run_command(
  command: DbCommand,
) -> Free(Result(Nil, DbCommandError)) {
  Impure(AttemptRunCommand(command, Pure))
}

pub fn run_command(command: DbCommand) -> Free(Nil) {
  use command_result <- and_then(attempt_run_command(command))
  case command_result {
    Ok(_) -> Pure(Nil)
    Error(error) -> Fail(CommandError(error))
  }
}

pub fn attempt_run_in_transaction(
  commands: List(DbCommand),
) -> Free(Result(Nil, DbTransactionError)) {
  Impure(AttemptRunInTransaction(commands, Pure))
}

pub fn run_in_transaction(commands: List(DbCommand)) -> Free(Nil) {
  use transaction_result <- and_then(attempt_run_in_transaction(commands))
  case transaction_result {
    Ok(_) -> Pure(Nil)
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
    DbCountUserActionsByIp(windows:, ip:, action:, next:) ->
      handlers.count_user_actions_by_ip(windows, ip, action)
      |> result.map(next)
    DbCountUserActionsByUser(windows:, user_id:, action:, next:) ->
      handlers.count_user_actions_by_user(windows, user_id, action)
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
    DbCountUserActionsByIp(windows:, ip:, action:, next:) ->
      DbCountUserActionsByIp(
        windows: windows,
        ip: ip,
        action: action,
        next: fn(value) { f(next(value)) },
      )
    DbCountUserActionsByUser(windows:, user_id:, action:, next:) ->
      DbCountUserActionsByUser(
        windows: windows,
        user_id: user_id,
        action: action,
        next: fn(value) { f(next(value)) },
      )
  }
}

fn map_effect(effect: Effect(a), f: fn(a) -> b) -> Effect(b) {
  case effect {
    MeasureEffectDuration(name, duration_ms, next) ->
      MeasureEffectDuration(name, duration_ms, f(next))
    NewToken(length, next) -> NewToken(length, fn(value) { f(next(value)) })
    SystemTime(next) -> SystemTime(fn(value) { f(next(value)) })
    UuidV7(next) -> UuidV7(fn(value) { f(next(value)) })
    Log(level, fields, next) -> Log(level, fields, f(next))
    AttemptPostRunRequest(cfg, request, next) ->
      AttemptPostRunRequest(cfg, request, fn(value) { f(next(value)) })
    AttemptSendEmail(message, next) ->
      AttemptSendEmail(message, fn(value) { f(next(value)) })
    AttemptRunQuery(query, on_error) ->
      AttemptRunQuery(map_db_query(query, f), fn(error) { f(on_error(error)) })
    AttemptRunCommand(command, next) ->
      AttemptRunCommand(command, fn(value) { f(next(value)) })
    AttemptRunInTransaction(commands, next) ->
      AttemptRunInTransaction(commands, fn(value) { f(next(value)) })
  }
}

fn db_query_name(query: DbQuery(a)) -> DbQueryName {
  case query {
    DbGetUserByEmail(_, _) -> DbGetUserByEmailQuery
    DbListLoginTokensByUser(_, _, _) -> DbListLoginTokensByUserQuery
    DbGetSessionByToken(_, _) -> DbGetSessionByTokenQuery
    DbGetNextJob(_, _, _, _) -> DbGetNextJobQuery
    DbCountUserActionsByIp(_, _, _, _) -> DbCountUserActionsByIpQuery
    DbCountUserActionsByUser(_, _, _, _) -> DbCountUserActionsByUserQuery
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
    DbInsertUserAction(_, _, _, _, _, _) -> DbInsertUserActionCommand
    DbMarkJobDone(_, _) -> DbMarkJobDoneCommand
    DbRescheduleJob(_, _, _, _) -> DbRescheduleJobCommand
  }
}

pub fn from_result(value: Result(a, Error)) -> Free(a) {
  case value {
    Ok(v) -> Pure(v)
    Error(err) -> Fail(err)
  }
}

fn measure_effect(
  state: State,
  effect_name: EffectName,
  started_at_ns: Int,
) -> State {
  let elapsed_ns = erlang.perf_counter_ns() - started_at_ns
  let safe_elapsed_ns = int.max(elapsed_ns, 0)
  add_effect_timings(state, effect_name, safe_elapsed_ns)
}

fn add_effect_timings(
  state: State,
  effect_name: EffectName,
  duration_ns: Int,
) -> State {
  State(..state, effect_timings: [
    #(effect_name, duration_ns),
    ..state.effect_timings
  ])
}

fn add_info_fields(state: State, fields: log.Fields) -> State {
  State(..state, info_fields: dict.merge(state.info_fields, fields))
}

fn add_warning_fields(state: State, fields: log.Fields) -> State {
  State(..state, warning_fields: dict.merge(state.warning_fields, fields))
}
