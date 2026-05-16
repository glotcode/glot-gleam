import gleam/dynamic/decode
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import glot_core/admin/availability_config_dto
import glot_core/admin/account_dto as admin_account_dto
import glot_core/admin/api_log_dto
import glot_core/admin/auth_config_dto
import glot_core/admin/cleanup_config_dto
import glot_core/admin/debug_config_dto
import glot_core/admin/docker_run_config_dto
import glot_core/admin/email_template_dto
import glot_core/admin/job_dto
import glot_core/admin/job_log_dto
import glot_core/admin/job_type_policy_dto
import glot_core/admin/periodic_job_dto
import glot_core/admin/rate_limit_config_dto
import glot_core/admin/run_log_dto
import glot_core/admin/snippet_dto as admin_snippet_dto
import glot_core/admin/user_dto
import glot_core/admin_action
import glot_core/public_action
import glot_core/auth/account_dto
import glot_core/auth/login_dto
import glot_core/auth/login_token_dto
import glot_core/auth/refresh_session_dto
import glot_core/auth/session_dto
import glot_core/email/email_address_model.{type EmailAddress}
import glot_core/pageview_dto
import glot_core/pagination_model
import glot_core/run
import glot_core/snippet/snippet_dto
import lustre/effect
import rsvp

pub type PublicApiRequest(a) {
  PublicApiRequest(action: public_action.PublicAction, data: a)
}

pub type AdminApiRequest(a) {
  AdminApiRequest(action: admin_action.AdminAction, data: a)
}

pub type ApiError {
  ApiError(code: String, message: String)
}

pub type ApiResponse(a) {
  ApiSuccess(data: a)
  ApiFailure(error: ApiError)
  HttpFailure(rsvp.Error(String))
}

pub fn error_message(error: ApiError) -> String {
  case error.code {
    "read_only_mode_enabled" ->
      error.message <> " Changes are temporarily disabled."
    "maintenance_mode_enabled" ->
      error.message <> " Most public actions are temporarily unavailable."
    _ -> error.message
  }
}

pub fn send_login_token(
  email: EmailAddress,
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req =
    PublicApiRequest(
      action: public_action.SendLoginTokenAction,
      data: login_token_dto.LoginTokenRequest(email),
    )

  send_public_api_request(req, login_token_dto.encode, nil_decoder(), to_msg)
}

pub fn track_pageview(
  request: pageview_dto.PageviewRequest,
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.TrackPageviewAction, request)

  send_public_api_request(req, pageview_dto.encode, nil_decoder(), to_msg)
}

pub fn login(
  email: EmailAddress,
  token: String,
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req =
    PublicApiRequest(
      action: public_action.LoginAction,
      data: login_dto.LoginRequest(email: email, token: token),
    )

  send_public_api_request(req, login_dto.encode, nil_decoder(), to_msg)
}

pub fn run_code(
  request: run.RunRequest,
  to_msg: fn(ApiResponse(run.RunResult)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.RunAction, request)

  send_public_api_request(
    req,
    run.encode_run_request,
    run.run_result_decoder(),
    to_msg,
  )
}

pub fn get_language_version(
  request: run.GetLanguageVersionRequest,
  to_msg: fn(ApiResponse(run.RunResult)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.GetLanguageVersionAction, request)

  send_public_api_request(
    req,
    run.encode_get_language_version_request,
    run.run_result_decoder(),
    to_msg,
  )
}

pub fn create_snippet(
  request: snippet_dto.CreateSnippetRequest,
  to_msg: fn(ApiResponse(snippet_dto.SnippetResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.CreateSnippetAction, request)

  send_public_api_request(
    req,
    fn(create_request) {
      json.object([
        #("data", snippet_dto.encode_data(create_request.data)),
      ])
    },
    snippet_dto.response_decoder(),
    to_msg,
  )
}

pub fn get_snippet(
  request: snippet_dto.GetSnippetRequest,
  to_msg: fn(ApiResponse(snippet_dto.SnippetResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.GetSnippetAction, request)

  send_public_api_request(
    req,
    fn(get_request) {
      json.object([
        #("slug", json.string(get_request.slug)),
      ])
    },
    snippet_dto.response_decoder(),
    to_msg,
  )
}

pub fn list_public_snippets(
  request: snippet_dto.ListPublicSnippetsRequest,
  to_msg: fn(ApiResponse(snippet_dto.ListSnippetsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.ListPublicSnippetsAction, request)

  send_public_api_request(
    req,
    fn(list_request) {
      json.object(
        list.append(
          pagination_model.encode_request_fields(list_request.pagination),
          [#("usernames", json.array(list_request.usernames, json.string))],
        ),
      )
    },
    snippet_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn list_session_snippets(
  request: snippet_dto.ListSessionSnippetsRequest,
  to_msg: fn(ApiResponse(snippet_dto.ListSnippetsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.ListSessionSnippetsAction, request)

  send_public_api_request(
    req,
    fn(list_request) {
      json.object(pagination_model.encode_request_fields(
        list_request.pagination,
      ))
    },
    snippet_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn update_snippet(
  request: snippet_dto.UpdateSnippetRequest,
  to_msg: fn(ApiResponse(snippet_dto.SnippetResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.UpdateSnippetAction, request)

  send_public_api_request(
    req,
    fn(update_request) {
      json.object([
        #("slug", json.string(update_request.slug)),
        #("data", snippet_dto.encode_data(update_request.data)),
      ])
    },
    snippet_dto.response_decoder(),
    to_msg,
  )
}

pub fn delete_snippet(
  request: snippet_dto.DeleteSnippetRequest,
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.DeleteSnippetAction, request)

  send_public_api_request(
    req,
    fn(delete_request) {
      json.object([
        #("slug", json.string(delete_request.slug)),
      ])
    },
    nil_decoder(),
    to_msg,
  )
}

pub fn get_session(
  to_msg: fn(ApiResponse(option.Option(session_dto.SessionResponse))) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.GetSessionAction, Nil)

  send_public_api_request(
    req,
    fn(_) { json.null() },
    decode.optional(session_dto.decoder()),
    to_msg,
  )
}

pub fn refresh_session(
  to_msg: fn(ApiResponse(refresh_session_dto.RefreshSessionResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.RefreshSessionAction, Nil)

  send_public_api_request(
    req,
    fn(_) { json.null() },
    refresh_session_dto.decoder(),
    to_msg,
  )
}

pub fn get_account(
  to_msg: fn(ApiResponse(account_dto.AccountResponse)) -> msg,
) -> effect.Effect(msg) {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  let req = PublicApiRequest(public_action.GetAccountAction, Nil)

  send_public_api_request(
    req,
    fn(_) { json.null() },
    account_dto.decoder(is_email),
    to_msg,
  )
}

pub fn logout(to_msg: fn(ApiResponse(Nil)) -> msg) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.LogoutAction, Nil)

  send_public_api_request(req, fn(_) { json.null() }, nil_decoder(), to_msg)
}

pub fn schedule_delete_account(
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.ScheduleDeleteAccountAction, Nil)

  send_public_api_request(req, fn(_) { json.null() }, nil_decoder(), to_msg)
}

pub fn cancel_delete_account(
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req = PublicApiRequest(public_action.CancelDeleteAccountAction, Nil)

  send_public_api_request(req, fn(_) { json.null() }, nil_decoder(), to_msg)
}

pub fn update_account(
  request: account_dto.UpdateAccountRequest,
  to_msg: fn(ApiResponse(account_dto.AccountResponse)) -> msg,
) -> effect.Effect(msg) {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  let req = PublicApiRequest(public_action.UpdateAccountAction, request)

  send_public_api_request(
    req,
    fn(update_request) {
      json.object([
        #("username", json.string(update_request.username)),
      ])
    },
    account_dto.decoder(is_email),
    to_msg,
  )
}

pub fn get_admin_rate_limit_policies(
  to_msg: fn(ApiResponse(rate_limit_config_dto.RateLimitPoliciesResponse)) ->
    msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminRateLimitPoliciesAction, Nil)

  send_admin_api_request(
    req,
    fn(_) { json.null() },
    rate_limit_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn get_admin_auth_config(
  to_msg: fn(ApiResponse(auth_config_dto.AuthConfigResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminAuthConfigAction, Nil)

  send_admin_api_request(
    req,
    fn(_) { json.null() },
    auth_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn get_admin_job_type_policies(
  to_msg: fn(ApiResponse(job_type_policy_dto.ListJobTypePoliciesResponse)) ->
    msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminJobTypePoliciesAction, Nil)

  send_admin_api_request(
    req,
    fn(_) { json.null() },
    job_type_policy_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_debug_config(
  to_msg: fn(ApiResponse(debug_config_dto.DebugConfigResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminDebugConfigAction, Nil)

  send_admin_api_request(
    req,
    fn(_) { json.null() },
    debug_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn get_admin_availability_config(
  to_msg: fn(ApiResponse(availability_config_dto.AvailabilityConfigResponse)) ->
    msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminAvailabilityConfigAction, Nil)

  send_admin_api_request(
    req,
    fn(_) { json.null() },
    availability_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn upsert_admin_debug_config(
  request: debug_config_dto.UpsertDebugConfigRequest,
  to_msg: fn(ApiResponse(debug_config_dto.DebugConfigResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.UpsertAdminDebugConfigAction, request)

  send_admin_api_request(
    req,
    debug_config_dto.encode_request,
    debug_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn upsert_admin_availability_config(
  request: availability_config_dto.UpsertAvailabilityConfigRequest,
  to_msg: fn(ApiResponse(availability_config_dto.AvailabilityConfigResponse)) ->
    msg,
) -> effect.Effect(msg) {
  let req =
    AdminApiRequest(admin_action.UpsertAdminAvailabilityConfigAction, request)

  send_admin_api_request(
    req,
    availability_config_dto.encode_request,
    availability_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn upsert_admin_job_type_policy(
  request: job_type_policy_dto.UpsertJobTypePolicyRequest,
  to_msg: fn(ApiResponse(job_type_policy_dto.JobTypePolicyResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.UpsertAdminJobTypePolicyAction, request)

  send_admin_api_request(
    req,
    job_type_policy_dto.encode_request,
    job_type_policy_dto.policy_response_decoder(),
    to_msg,
  )
}

pub fn upsert_admin_auth_config(
  request: auth_config_dto.UpsertAuthConfigRequest,
  to_msg: fn(ApiResponse(auth_config_dto.AuthConfigResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.UpsertAdminAuthConfigAction, request)

  send_admin_api_request(
    req,
    auth_config_dto.encode_request,
    auth_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn get_admin_cleanup_config(
  to_msg: fn(ApiResponse(cleanup_config_dto.CleanupConfigResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminCleanupConfigAction, Nil)

  send_admin_api_request(
    req,
    fn(_) { json.null() },
    cleanup_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn get_admin_periodic_jobs(
  to_msg: fn(ApiResponse(periodic_job_dto.ListPeriodicJobsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminPeriodicJobsAction, Nil)

  send_admin_api_request(
    req,
    fn(_) { json.null() },
    periodic_job_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_periodic_job(
  request: periodic_job_dto.GetPeriodicJobRequest,
  to_msg: fn(ApiResponse(periodic_job_dto.GetPeriodicJobResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminPeriodicJobAction, request)

  send_admin_api_request(
    req,
    periodic_job_dto.encode_get_request,
    periodic_job_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn update_admin_periodic_job(
  request: periodic_job_dto.UpdatePeriodicJobRequest,
  to_msg: fn(ApiResponse(periodic_job_dto.UpdatePeriodicJobResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.UpdateAdminPeriodicJobAction, request)

  send_admin_api_request(
    req,
    periodic_job_dto.encode_update_request,
    periodic_job_dto.update_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_jobs(
  request: job_dto.ListJobsRequest,
  to_msg: fn(ApiResponse(job_dto.ListJobsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminJobsAction, request)

  send_admin_api_request(
    req,
    job_dto.encode_list_request,
    job_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_job(
  request: job_dto.GetJobRequest,
  to_msg: fn(ApiResponse(job_dto.GetJobResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminJobAction, request)

  send_admin_api_request(
    req,
    job_dto.encode_get_request,
    job_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn create_admin_job(
  request: job_dto.CreateJobRequest,
  to_msg: fn(ApiResponse(job_dto.GetJobResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.CreateAdminJobAction, request)

  send_admin_api_request(
    req,
    job_dto.encode_create_request,
    job_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_email_templates(
  to_msg: fn(ApiResponse(email_template_dto.ListEmailTemplatesResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminEmailTemplatesAction, Nil)

  send_admin_api_request(
    req,
    fn(_) { json.null() },
    email_template_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_email_template(
  request: email_template_dto.GetEmailTemplateRequest,
  to_msg: fn(ApiResponse(email_template_dto.GetEmailTemplateResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminEmailTemplateAction, request)

  send_admin_api_request(
    req,
    email_template_dto.encode_get_request,
    email_template_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn update_admin_email_template(
  request: email_template_dto.UpdateEmailTemplateRequest,
  to_msg: fn(ApiResponse(email_template_dto.UpdateEmailTemplateResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.UpdateAdminEmailTemplateAction, request)

  send_admin_api_request(
    req,
    email_template_dto.encode_update_request,
    email_template_dto.update_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_snippets(
  request: admin_snippet_dto.ListSnippetsRequest,
  to_msg: fn(ApiResponse(admin_snippet_dto.ListSnippetsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminSnippetsAction, request)

  send_admin_api_request(
    req,
    admin_snippet_dto.encode_list_request,
    admin_snippet_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_snippet(
  request: admin_snippet_dto.GetSnippetRequest,
  to_msg: fn(ApiResponse(admin_snippet_dto.GetSnippetResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminSnippetAction, request)

  send_admin_api_request(
    req,
    admin_snippet_dto.encode_get_request,
    admin_snippet_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn delete_admin_snippet(
  request: snippet_dto.DeleteSnippetRequest,
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.DeleteAdminSnippetAction, request)

  send_admin_api_request(
    req,
    fn(delete_request) {
      json.object([
        #("slug", json.string(delete_request.slug)),
      ])
    },
    nil_decoder(),
    to_msg,
  )
}

pub fn get_admin_users(
  request: user_dto.ListUsersRequest,
  to_msg: fn(ApiResponse(user_dto.ListUsersResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminUsersAction, request)

  send_admin_api_request(
    req,
    user_dto.encode_list_request,
    user_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_user(
  request: user_dto.GetUserRequest,
  to_msg: fn(ApiResponse(user_dto.GetUserResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminUserAction, request)

  send_admin_api_request(
    req,
    user_dto.encode_get_request,
    user_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn update_admin_user(
  request: user_dto.UpdateUserRequest,
  to_msg: fn(ApiResponse(user_dto.UpdateUserResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.UpdateAdminUserAction, request)

  send_admin_api_request(
    req,
    user_dto.encode_update_request,
    user_dto.update_response_decoder(),
    to_msg,
  )
}

pub fn delete_admin_account(
  request: admin_account_dto.DeleteAccountRequest,
  to_msg: fn(ApiResponse(Nil)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.DeleteAdminAccountAction, request)

  send_admin_api_request(
    req,
    admin_account_dto.encode_delete_request,
    nil_decoder(),
    to_msg,
  )
}

pub fn get_admin_api_logs(
  request: api_log_dto.ListApiLogsRequest,
  to_msg: fn(ApiResponse(api_log_dto.ListApiLogsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminApiLogsAction, request)

  send_admin_api_request(
    req,
    api_log_dto.encode_list_request,
    api_log_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_api_log(
  request: api_log_dto.GetApiLogRequest,
  to_msg: fn(ApiResponse(api_log_dto.GetApiLogResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminApiLogAction, request)

  send_admin_api_request(
    req,
    api_log_dto.encode_get_request,
    api_log_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_run_logs(
  request: run_log_dto.ListRunLogsRequest,
  to_msg: fn(ApiResponse(run_log_dto.ListRunLogsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminRunLogsAction, request)

  send_admin_api_request(
    req,
    run_log_dto.encode_list_request,
    run_log_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_run_log(
  request: run_log_dto.GetRunLogRequest,
  to_msg: fn(ApiResponse(run_log_dto.GetRunLogResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminRunLogAction, request)

  send_admin_api_request(
    req,
    run_log_dto.encode_get_request,
    run_log_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_job_logs(
  request: job_log_dto.ListJobLogsRequest,
  to_msg: fn(ApiResponse(job_log_dto.ListJobLogsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminJobLogsAction, request)

  send_admin_api_request(
    req,
    job_log_dto.encode_list_request,
    job_log_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_job_log(
  request: job_log_dto.GetJobLogRequest,
  to_msg: fn(ApiResponse(job_log_dto.GetJobLogResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminJobLogAction, request)

  send_admin_api_request(
    req,
    job_log_dto.encode_get_request,
    job_log_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn upsert_admin_cleanup_config(
  request: cleanup_config_dto.UpsertCleanupConfigRequest,
  to_msg: fn(ApiResponse(cleanup_config_dto.CleanupConfigResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.UpsertAdminCleanupConfigAction, request)

  send_admin_api_request(
    req,
    cleanup_config_dto.encode_request,
    cleanup_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn upsert_admin_rate_limit_policy(
  request: rate_limit_config_dto.UpsertRateLimitPolicyRequest,
  to_msg: fn(ApiResponse(rate_limit_config_dto.RateLimitPolicyResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.UpsertAdminRateLimitPolicyAction, request)

  send_admin_api_request(
    req,
    rate_limit_config_dto.encode_request,
    rate_limit_config_dto.policy_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_docker_run_config(
  to_msg: fn(ApiResponse(docker_run_config_dto.DockerRunConfigResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.GetAdminDockerRunConfigAction, Nil)

  send_admin_api_request(
    req,
    fn(_) { json.null() },
    docker_run_config_dto.response_decoder(),
    to_msg,
  )
}

pub fn upsert_admin_docker_run_config(
  request: docker_run_config_dto.UpsertDockerRunConfigRequest,
  to_msg: fn(ApiResponse(docker_run_config_dto.DockerRunConfigResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = AdminApiRequest(admin_action.UpsertAdminDockerRunConfigAction, request)

  send_admin_api_request(
    req,
    docker_run_config_dto.encode_request,
    docker_run_config_dto.response_decoder(),
    to_msg,
  )
}

fn send_public_api_request(
  req: PublicApiRequest(a),
  encode_data: fn(a) -> json.Json,
  decode_data: decode.Decoder(b),
  to_msg: fn(ApiResponse(b)) -> msg,
) -> effect.Effect(msg) {
  let body = encode_public_api_request(req, encode_data)
  send_encoded_api_request(body, decode_data, to_msg)
}

fn send_admin_api_request(
  req: AdminApiRequest(a),
  encode_data: fn(a) -> json.Json,
  decode_data: decode.Decoder(b),
  to_msg: fn(ApiResponse(b)) -> msg,
) -> effect.Effect(msg) {
  let body = encode_admin_api_request(req, encode_data)
  send_encoded_api_request(body, decode_data, to_msg)
}

fn send_encoded_api_request(
  body: json.Json,
  decode_data: decode.Decoder(b),
  to_msg: fn(ApiResponse(b)) -> msg,
) -> effect.Effect(msg) {
  let handler =
    rsvp.expect_any_response(fn(result) {
      case result {
        Ok(http_response) ->
          case decode_api_response(http_response, decode_data) {
            Ok(response) -> to_msg(response)
            Error(error) -> to_msg(HttpFailure(error))
          }
        Error(error) -> to_msg(HttpFailure(error))
      }
    })

  rsvp.post("/api/mux", body, handler)
}

fn encode_public_api_request(
  req: PublicApiRequest(a),
  encode_data: fn(a) -> json.Json,
) -> json.Json {
  json.object([
    #("action", public_action.encode(req.action)),
    #("data", encode_data(req.data)),
  ])
}

fn encode_admin_api_request(
  req: AdminApiRequest(a),
  encode_data: fn(a) -> json.Json,
) -> json.Json {
  json.object([
    #("action", admin_action.encode(req.action)),
    #("data", encode_data(req.data)),
  ])
}

fn api_response_decoder(
  data_decoder: decode.Decoder(a),
) -> decode.Decoder(ApiResponse(a)) {
  use data <- decode.field("data", data_decoder)
  decode.success(ApiSuccess(data))
}

fn api_error_decoder() -> decode.Decoder(ApiError) {
  use code <- decode.field("code", decode.string)
  use message <- decode.field("message", decode.string)
  decode.success(ApiError(code: code, message: message))
}

fn decode_api_response(
  http_response: response.Response(String),
  data_decoder: decode.Decoder(a),
) -> Result(ApiResponse(a), rsvp.Error(String)) {
  use _ <- result.try(ensure_json_response(http_response))

  case http_response.status {
    status if status >= 200 && status < 300 ->
      json.parse(http_response.body, api_response_decoder(data_decoder))
      |> result.map_error(rsvp.JsonError)
    status if status >= 400 && status < 600 ->
      json.parse(http_response.body, error_response_decoder())
      |> result.map_error(rsvp.JsonError)
    _ -> Error(rsvp.UnhandledResponse(http_response))
  }
}

fn ensure_json_response(
  http_response: response.Response(String),
) -> Result(Nil, rsvp.Error(String)) {
  case response.get_header(http_response, "content-type") {
    Ok("application/json") -> Ok(Nil)
    Ok("application/json;" <> _) -> Ok(Nil)
    _ -> Error(rsvp.UnhandledResponse(http_response))
  }
}

fn error_response_decoder() -> decode.Decoder(ApiResponse(a)) {
  use error <- decode.field("error", api_error_decoder())
  decode.success(ApiFailure(error))
}

fn nil_decoder() -> decode.Decoder(Nil) {
  decode.then(decode.optional(decode.bool), fn(value) {
    case value {
      option.None -> decode.success(Nil)
      option.Some(_) -> decode.failure(Nil, "Nil")
    }
  })
}
