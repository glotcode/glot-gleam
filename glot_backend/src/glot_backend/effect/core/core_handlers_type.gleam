import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/effect/error
import glot_backend/email_message
import glot_backend/job
import glot_core/rate_limit
import youid/uuid.{type Uuid}

pub type CoreHandlers {
  CoreHandlers(
    new_token: fn(Int) -> String,
    system_time: fn() -> Timestamp,
    uuid_v7: fn() -> Uuid,
    send_email: fn(email_message.EmailMessage) ->
      Result(Nil, error.SendEmailError),
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
  )
}
