import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option

pub type PublicAction {
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
}

pub type AdminAction {
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
  GetAdminEmailTemplatesAction
  GetAdminEmailTemplateAction
  UpdateAdminEmailTemplateAction
  GetAdminSnippetsAction
  GetAdminSnippetAction
  DeleteAdminSnippetAction
  GetAdminUsersAction
  GetAdminUserAction
  UpdateAdminUserAction
  DeleteAdminAccountAction
  GetAdminApiLogsAction
  GetAdminApiLogAction
  GetAdminRunLogsAction
  GetAdminRunLogAction
  GetAdminJobLogsAction
  GetAdminJobLogAction
  GetAdminRateLimitPoliciesAction
  UpsertAdminRateLimitPolicyAction
  GetAdminJobTypePoliciesAction
  UpsertAdminJobTypePolicyAction
  GetAdminDockerRunConfigAction
  UpsertAdminDockerRunConfigAction
}

pub type ApiAction {
  PublicAction(PublicAction)
  AdminAction(AdminAction)
}

pub fn public(action: PublicAction) -> ApiAction {
  PublicAction(action)
}

pub fn admin(action: AdminAction) -> ApiAction {
  AdminAction(action)
}

pub fn list() -> List(ApiAction) {
  list.append(
    list.map(list_public(), public),
    list.map(list_admin(), admin),
  )
}

pub fn list_public() -> List(PublicAction) {
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
  ]
}

pub fn list_admin() -> List(AdminAction) {
  [
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
    GetAdminEmailTemplatesAction,
    GetAdminEmailTemplateAction,
    UpdateAdminEmailTemplateAction,
    GetAdminSnippetsAction,
    GetAdminSnippetAction,
    DeleteAdminSnippetAction,
    GetAdminUsersAction,
    GetAdminUserAction,
    UpdateAdminUserAction,
    DeleteAdminAccountAction,
    GetAdminApiLogsAction,
    GetAdminApiLogAction,
    GetAdminRunLogsAction,
    GetAdminRunLogAction,
    GetAdminJobLogsAction,
    GetAdminJobLogAction,
    GetAdminRateLimitPoliciesAction,
    UpsertAdminRateLimitPolicyAction,
    GetAdminJobTypePoliciesAction,
    UpsertAdminJobTypePolicyAction,
    GetAdminDockerRunConfigAction,
    UpsertAdminDockerRunConfigAction,
  ]
}

pub fn decoder() -> decode.Decoder(ApiAction) {
  use action <- decode.then(decode.string)
  case from_string(action) {
    option.Some(action) -> decode.success(action)
    option.None -> decode.failure(public(RunAction), "ApiAction")
  }
}

pub fn public_decoder() -> decode.Decoder(PublicAction) {
  use action <- decode.then(decode.string)
  case from_public_string(action) {
    option.Some(action) -> decode.success(action)
    option.None -> decode.failure(RunAction, "PublicAction")
  }
}

pub fn admin_decoder() -> decode.Decoder(AdminAction) {
  use action <- decode.then(decode.string)
  case from_admin_string(action) {
    option.Some(action) -> decode.success(action)
    option.None ->
      decode.failure(GetAdminRateLimitPoliciesAction, "AdminAction")
  }
}

pub fn encode(action: ApiAction) -> json.Json {
  action |> to_string |> json.string
}

pub fn encode_public(action: PublicAction) -> json.Json {
  action |> public_to_string |> json.string
}

pub fn encode_admin(action: AdminAction) -> json.Json {
  action |> admin_to_string |> json.string
}

pub fn to_string(action: ApiAction) -> String {
  case action {
    PublicAction(action) -> public_to_string(action)
    AdminAction(action) -> admin_to_string(action)
  }
}

pub fn public_to_string(action: PublicAction) -> String {
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
  }
}

pub fn admin_to_string(action: AdminAction) -> String {
  case action {
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
    GetAdminEmailTemplatesAction -> "get_admin_email_templates"
    GetAdminEmailTemplateAction -> "get_admin_email_template"
    UpdateAdminEmailTemplateAction -> "update_admin_email_template"
    GetAdminSnippetsAction -> "get_admin_snippets"
    GetAdminSnippetAction -> "get_admin_snippet"
    DeleteAdminSnippetAction -> "delete_admin_snippet"
    GetAdminUsersAction -> "get_admin_users"
    GetAdminUserAction -> "get_admin_user"
    UpdateAdminUserAction -> "update_admin_user"
    DeleteAdminAccountAction -> "delete_admin_account"
    GetAdminApiLogsAction -> "get_admin_api_logs"
    GetAdminApiLogAction -> "get_admin_api_log"
    GetAdminRunLogsAction -> "get_admin_run_logs"
    GetAdminRunLogAction -> "get_admin_run_log"
    GetAdminJobLogsAction -> "get_admin_job_logs"
    GetAdminJobLogAction -> "get_admin_job_log"
    GetAdminRateLimitPoliciesAction -> "get_admin_rate_limit_policies"
    UpsertAdminRateLimitPolicyAction -> "upsert_admin_rate_limit_policy"
    GetAdminJobTypePoliciesAction -> "get_admin_job_type_policies"
    UpsertAdminJobTypePolicyAction -> "upsert_admin_job_type_policy"
    GetAdminDockerRunConfigAction -> "get_admin_docker_run_config"
    UpsertAdminDockerRunConfigAction -> "upsert_admin_docker_run_config"
  }
}

pub fn from_string(action: String) -> option.Option(ApiAction) {
  case from_public_string(action) {
    option.Some(action) -> option.Some(public(action))
    option.None ->
      from_admin_string(action)
      |> option.map(admin)
  }
}

pub fn from_public_string(action: String) -> option.Option(PublicAction) {
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
    _ -> option.None
  }
}

pub fn from_admin_string(action: String) -> option.Option(AdminAction) {
  case action {
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
    "get_admin_email_templates" -> option.Some(GetAdminEmailTemplatesAction)
    "get_admin_email_template" -> option.Some(GetAdminEmailTemplateAction)
    "update_admin_email_template" -> option.Some(UpdateAdminEmailTemplateAction)
    "get_admin_snippets" -> option.Some(GetAdminSnippetsAction)
    "get_admin_snippet" -> option.Some(GetAdminSnippetAction)
    "delete_admin_snippet" -> option.Some(DeleteAdminSnippetAction)
    "get_admin_users" -> option.Some(GetAdminUsersAction)
    "get_admin_user" -> option.Some(GetAdminUserAction)
    "update_admin_user" -> option.Some(UpdateAdminUserAction)
    "delete_admin_account" -> option.Some(DeleteAdminAccountAction)
    "get_admin_api_logs" -> option.Some(GetAdminApiLogsAction)
    "get_admin_api_log" -> option.Some(GetAdminApiLogAction)
    "get_admin_run_logs" -> option.Some(GetAdminRunLogsAction)
    "get_admin_run_log" -> option.Some(GetAdminRunLogAction)
    "get_admin_job_logs" -> option.Some(GetAdminJobLogsAction)
    "get_admin_job_log" -> option.Some(GetAdminJobLogAction)
    "get_admin_rate_limit_policies" ->
      option.Some(GetAdminRateLimitPoliciesAction)
    "upsert_admin_rate_limit_policy" ->
      option.Some(UpsertAdminRateLimitPolicyAction)
    "get_admin_job_type_policies" -> option.Some(GetAdminJobTypePoliciesAction)
    "upsert_admin_job_type_policy" ->
      option.Some(UpsertAdminJobTypePolicyAction)
    "get_admin_docker_run_config" -> option.Some(GetAdminDockerRunConfigAction)
    "upsert_admin_docker_run_config" ->
      option.Some(UpsertAdminDockerRunConfigAction)
    _ -> option.None
  }
}
