import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/context
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/email_message
import glot_backend/job
import glot_core/auth as auth_core
import glot_core/email
import glot_core/rate_limit
import glot_core/run
import glot_core/snippet
import glot_core/user
import youid/uuid.{type Uuid}

pub type Handlers {
  Handlers(
    new_token: fn(Int) -> String,
    system_time: fn() -> Timestamp,
    uuid_v7: fn() -> Uuid,
    post_run_request: fn(context.Config, run.RunRequest) ->
      Result(run.RunResult, error.RunRequestError),
    send_email: fn(email_message.EmailMessage) ->
      Result(Nil, error.SendEmailError),
    get_user_by_email: fn(email.Email) ->
      Result(option.Option(user.User), error.DbQueryError),
    list_login_tokens_by_user: fn(Uuid, Int) ->
      Result(List(auth_core.LoginToken), error.DbQueryError),
    get_session_by_token: fn(String) ->
      Result(option.Option(auth_core.Session), error.DbQueryError),
    get_next_job: fn(Timestamp, job.Status, job.Status) ->
      Result(option.Option(job.Job), error.DbQueryError),
    count_user_actions_by_ip: fn(
      List(rate_limit.Window),
      option.Option(String),
      ApiAction,
    ) ->
      Result(List(rate_limit.WindowCount), error.DbQueryError),
    count_user_actions_by_user: fn(
      List(rate_limit.Window),
      option.Option(Uuid),
      ApiAction,
    ) ->
      Result(List(rate_limit.WindowCount), error.DbQueryError),
    insert_user: fn(Uuid, String, Timestamp) -> Result(Nil, error.DbCommandError),
    insert_session: fn(
      Uuid,
      Uuid,
      String,
      option.Option(String),
      option.Option(String),
      Timestamp,
    ) -> Result(Nil, error.DbCommandError),
    insert_login_token: fn(
      Uuid,
      Uuid,
      String,
      Timestamp,
      option.Option(Timestamp),
    ) -> Result(Nil, error.DbCommandError),
    update_login_token: fn(
      Uuid,
      String,
      Timestamp,
      option.Option(Timestamp),
      Uuid,
    ) -> Result(Nil, error.DbCommandError),
    insert_job: fn(job.Job) -> Result(Nil, error.DbCommandError),
    insert_user_action: fn(
      Uuid,
      Uuid,
      ApiAction,
      option.Option(String),
      option.Option(Uuid),
      Timestamp,
    ) -> Result(Nil, error.DbCommandError),
    mark_job_done: fn(Uuid, Timestamp) -> Result(Nil, error.DbCommandError),
    reschedule_job: fn(
      Uuid,
      Timestamp,
      option.Option(String),
      Timestamp,
    ) -> Result(Nil, error.DbCommandError),
    insert_snippet: fn(
      Uuid,
      Uuid,
      snippet.Snippet,
      Timestamp,
      Timestamp,
    ) -> Result(Nil, error.DbCommandError),
    run_in_transaction: fn(List(effect_model.Program(Nil))) ->
      #(Result(Nil, error.DbTransactionError), effect_model.State),
  )
}
