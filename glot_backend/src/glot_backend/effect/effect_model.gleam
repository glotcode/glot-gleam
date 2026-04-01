import glot_backend/effect/auth/auth
import glot_backend/effect/core/core
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/error
import glot_backend/effect/snippet/snippet

pub type Program(a) {
  Pure(a)
  Fail(error.Error)
  Impure(Effect(Program(a)))
}

pub type DbQueryName {
  CoreQueryName(core.CoreQueryName)
  AuthQueryName(auth.AuthQueryName)
}

pub type DbCommandName {
  CoreCommandName(core.CoreCommandName)
  AuthCommandName(auth.AuthCommandName)
  SnippetCommandName(snippet.SnippetCommandName)
}

pub type EffectCategory {
  UtilEffectCategory
  LogEffectCategory
  DockerRunEffectCategory
  EmailEffectCategory
  DbReadEffectCategory
  DbWriteEffectCategory
}

pub fn effect_category_to_string(category: EffectCategory) -> String {
  case category {
    UtilEffectCategory -> "util"
    LogEffectCategory -> "log"
    DockerRunEffectCategory -> "docker_run"
    EmailEffectCategory -> "email"
    DbReadEffectCategory -> "db_read"
    DbWriteEffectCategory -> "db_write"
  }
}

pub type EffectName {
  NewTokenEffect
  SystemTimeEffect
  UuidV7Effect
  LogEffect
  DockerRunRequestEffect
  SendEmailEffect
  RunQueryEffect(DbQueryName)
  RunCommandEffect(DbCommandName)
  RunInTransactionEffect(List(EffectName))
}

pub type Effect(next) {
  CoreEffect(core.CoreEffect(next))
  AuthEffect(auth.AuthEffect(next))
  SnippetEffect(snippet.SnippetEffect(next))
  DockerRunEffect(docker_run.DockerRunEffect(next))
  TransactionEffect(
    List(Program(Nil)),
    fn(Result(Nil, error.DbTransactionError)) -> next,
  )
}

pub fn effect_name_to_string(effect_name: EffectName) -> String {
  case effect_name {
    NewTokenEffect -> "new_token"
    SystemTimeEffect -> "system_time"
    UuidV7Effect -> "uuid_v7"
    LogEffect -> "log"
    DockerRunRequestEffect -> "post_run_request"
    SendEmailEffect -> "send_email"
    RunQueryEffect(query_name) -> db_query_name_to_string(query_name)
    RunCommandEffect(command_name) -> db_command_name_to_string(command_name)
    RunInTransactionEffect(_) -> "run_in_transaction"
  }
}

pub fn db_query_name_to_string(query_name: DbQueryName) -> String {
  case query_name {
    AuthQueryName(auth.GetUserByEmailQuery) -> "db_get_user_by_email"
    AuthQueryName(auth.ListLoginTokensByUserQuery) ->
      "db_list_login_tokens_by_user"
    AuthQueryName(auth.GetSessionByTokenQuery) -> "db_get_session_by_token"
    CoreQueryName(core.GetNextJobQuery) -> "db_get_next_job"
    CoreQueryName(core.CountUserActionsByIpQuery) ->
      "db_count_user_actions_by_ip"
    CoreQueryName(core.CountUserActionsByUserQuery) ->
      "db_count_user_actions_by_user"
  }
}

pub fn db_command_name_to_string(command_name: DbCommandName) -> String {
  case command_name {
    AuthCommandName(auth.InsertUserCommand) -> "db_insert_user"
    CoreCommandName(core.InsertJobCommand) -> "db_insert_job"
    SnippetCommandName(snippet.InsertSnippetCommand) -> "db_insert_snippet"
    AuthCommandName(auth.InsertSessionCommand) -> "db_insert_session"
    AuthCommandName(auth.InsertLoginTokenCommand) -> "db_insert_login_token"
    AuthCommandName(auth.UpdateLoginTokenCommand) -> "db_update_login_token"
    CoreCommandName(core.InsertUserActionCommand) -> "db_insert_user_action"
    CoreCommandName(core.MarkJobDoneCommand) -> "db_mark_job_done"
    CoreCommandName(core.RescheduleJobCommand) -> "db_reschedule_job"
  }
}
