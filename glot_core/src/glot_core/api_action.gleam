import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type ApiAction {
  TrackPageviewAction
  RunAction
  GetLanguageVersionAction
  GetSessionAction
  LogoutAction
  GetAccountAction
  UpdateAccountAction
  ScheduleDeleteAccountAction
  CancelDeleteAccountAction
  GetSnippetAction
  ListPublicSnippetsAction
  ListSessionSnippetsAction
  CreateSnippetAction
  UpdateSnippetAction
  DeleteSnippetAction
  SendLoginTokenAction
  LoginAction
  GetAdminDebugConfigAction
  UpsertAdminDebugConfigAction
  GetAdminAuthConfigAction
  UpsertAdminAuthConfigAction
  GetAdminCleanupConfigAction
  UpsertAdminCleanupConfigAction
  GetAdminPeriodicJobsAction
  GetAdminPeriodicJobAction
  UpdateAdminPeriodicJobAction
  GetAdminJobsAction
  GetAdminJobAction
  CreateAdminJobAction
  GetAdminApiLogsAction
  GetAdminApiLogAction
  GetAdminJobLogsAction
  GetAdminJobLogAction
  GetAdminRateLimitPoliciesAction
  UpsertAdminRateLimitPolicyAction
  GetAdminDockerRunConfigAction
  UpsertAdminDockerRunConfigAction
}

pub fn list() -> List(ApiAction) {
  [
    TrackPageviewAction,
    RunAction,
    GetLanguageVersionAction,
    GetSessionAction,
    LogoutAction,
    GetAccountAction,
    UpdateAccountAction,
    ScheduleDeleteAccountAction,
    CancelDeleteAccountAction,
    GetSnippetAction,
    ListPublicSnippetsAction,
    ListSessionSnippetsAction,
    CreateSnippetAction,
    UpdateSnippetAction,
    DeleteSnippetAction,
    SendLoginTokenAction,
    LoginAction,
    GetAdminDebugConfigAction,
    UpsertAdminDebugConfigAction,
    GetAdminAuthConfigAction,
    UpsertAdminAuthConfigAction,
    GetAdminCleanupConfigAction,
    UpsertAdminCleanupConfigAction,
    GetAdminPeriodicJobsAction,
    GetAdminPeriodicJobAction,
    UpdateAdminPeriodicJobAction,
    GetAdminJobsAction,
    GetAdminJobAction,
    CreateAdminJobAction,
    GetAdminApiLogsAction,
    GetAdminApiLogAction,
    GetAdminJobLogsAction,
    GetAdminJobLogAction,
    GetAdminRateLimitPoliciesAction,
    UpsertAdminRateLimitPolicyAction,
    GetAdminDockerRunConfigAction,
    UpsertAdminDockerRunConfigAction,
  ]
}

pub fn decoder() -> decode.Decoder(ApiAction) {
  use action <- decode.then(decode.string)
  case from_string(action) {
    option.Some(action) -> decode.success(action)
    option.None -> decode.failure(RunAction, "ApiAction")
  }
}

pub fn encode(action: ApiAction) -> json.Json {
  action |> to_string |> json.string
}

pub fn to_string(action: ApiAction) -> String {
  case action {
    TrackPageviewAction -> "track_pageview"
    RunAction -> "run"
    GetLanguageVersionAction -> "get_language_version"
    GetSessionAction -> "get_session"
    LogoutAction -> "logout"
    GetAccountAction -> "get_account"
    UpdateAccountAction -> "update_account"
    ScheduleDeleteAccountAction -> "schedule_delete_account"
    CancelDeleteAccountAction -> "cancel_delete_account"
    GetSnippetAction -> "get_snippet"
    ListPublicSnippetsAction -> "list_public_snippets"
    ListSessionSnippetsAction -> "list_session_snippets"
    CreateSnippetAction -> "create_snippet"
    UpdateSnippetAction -> "update_snippet"
    DeleteSnippetAction -> "delete_snippet"
    SendLoginTokenAction -> "send_login_token"
    LoginAction -> "login"
    GetAdminDebugConfigAction -> "get_admin_debug_config"
    UpsertAdminDebugConfigAction -> "upsert_admin_debug_config"
    GetAdminAuthConfigAction -> "get_admin_auth_config"
    UpsertAdminAuthConfigAction -> "upsert_admin_auth_config"
    GetAdminCleanupConfigAction -> "get_admin_cleanup_config"
    UpsertAdminCleanupConfigAction -> "upsert_admin_cleanup_config"
    GetAdminPeriodicJobsAction -> "get_admin_periodic_jobs"
    GetAdminPeriodicJobAction -> "get_admin_periodic_job"
    UpdateAdminPeriodicJobAction -> "update_admin_periodic_job"
    GetAdminJobsAction -> "get_admin_jobs"
    GetAdminJobAction -> "get_admin_job"
    CreateAdminJobAction -> "create_admin_job"
    GetAdminApiLogsAction -> "get_admin_api_logs"
    GetAdminApiLogAction -> "get_admin_api_log"
    GetAdminJobLogsAction -> "get_admin_job_logs"
    GetAdminJobLogAction -> "get_admin_job_log"
    GetAdminRateLimitPoliciesAction -> "get_admin_rate_limit_policies"
    UpsertAdminRateLimitPolicyAction -> "upsert_admin_rate_limit_policy"
    GetAdminDockerRunConfigAction -> "get_admin_docker_run_config"
    UpsertAdminDockerRunConfigAction -> "upsert_admin_docker_run_config"
  }
}

pub fn from_string(action: String) -> option.Option(ApiAction) {
  case action {
    "track_pageview" -> option.Some(TrackPageviewAction)
    "run" -> option.Some(RunAction)
    "get_language_version" -> option.Some(GetLanguageVersionAction)
    "get_session" -> option.Some(GetSessionAction)
    "logout" -> option.Some(LogoutAction)
    "get_account" -> option.Some(GetAccountAction)
    "update_account" -> option.Some(UpdateAccountAction)
    "schedule_delete_account" -> option.Some(ScheduleDeleteAccountAction)
    "cancel_delete_account" -> option.Some(CancelDeleteAccountAction)
    "get_snippet" -> option.Some(GetSnippetAction)
    "list_public_snippets" -> option.Some(ListPublicSnippetsAction)
    "list_session_snippets" -> option.Some(ListSessionSnippetsAction)
    "create_snippet" -> option.Some(CreateSnippetAction)
    "update_snippet" -> option.Some(UpdateSnippetAction)
    "delete_snippet" -> option.Some(DeleteSnippetAction)
    "send_login_token" -> option.Some(SendLoginTokenAction)
    "login" -> option.Some(LoginAction)
    "get_admin_debug_config" -> option.Some(GetAdminDebugConfigAction)
    "upsert_admin_debug_config" -> option.Some(UpsertAdminDebugConfigAction)
    "get_admin_auth_config" -> option.Some(GetAdminAuthConfigAction)
    "upsert_admin_auth_config" -> option.Some(UpsertAdminAuthConfigAction)
    "get_admin_cleanup_config" -> option.Some(GetAdminCleanupConfigAction)
    "upsert_admin_cleanup_config" -> option.Some(UpsertAdminCleanupConfigAction)
    "get_admin_periodic_jobs" -> option.Some(GetAdminPeriodicJobsAction)
    "get_admin_periodic_job" -> option.Some(GetAdminPeriodicJobAction)
    "update_admin_periodic_job" -> option.Some(UpdateAdminPeriodicJobAction)
    "get_admin_jobs" -> option.Some(GetAdminJobsAction)
    "get_admin_job" -> option.Some(GetAdminJobAction)
    "create_admin_job" -> option.Some(CreateAdminJobAction)
    "get_admin_api_logs" -> option.Some(GetAdminApiLogsAction)
    "get_admin_api_log" -> option.Some(GetAdminApiLogAction)
    "get_admin_job_logs" -> option.Some(GetAdminJobLogsAction)
    "get_admin_job_log" -> option.Some(GetAdminJobLogAction)
    "get_admin_rate_limit_policies" ->
      option.Some(GetAdminRateLimitPoliciesAction)
    "upsert_admin_rate_limit_policy" ->
      option.Some(UpsertAdminRateLimitPolicyAction)
    "get_admin_docker_run_config" -> option.Some(GetAdminDockerRunConfigAction)
    "upsert_admin_docker_run_config" ->
      option.Some(UpsertAdminDockerRunConfigAction)
    _ -> option.None
  }
}
