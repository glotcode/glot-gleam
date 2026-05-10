import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import glot_backend/context
import glot_backend/domain/account/cancel_delete_account_domain
import glot_backend/domain/account/get_account_domain
import glot_backend/domain/account/schedule_delete_account_domain
import glot_backend/domain/account/update_account_domain
import glot_backend/domain/admin/get_api_log_domain
import glot_backend/domain/admin/get_api_logs_domain
import glot_backend/domain/admin/get_auth_config_domain
import glot_backend/domain/admin/get_cleanup_config_domain
import glot_backend/domain/admin/get_debug_config_domain
import glot_backend/domain/admin/get_docker_run_config_domain
import glot_backend/domain/admin/create_job_domain
import glot_backend/domain/admin/get_job_domain
import glot_backend/domain/admin/get_job_log_domain
import glot_backend/domain/admin/get_job_logs_domain
import glot_backend/domain/admin/get_jobs_domain
import glot_backend/domain/admin/get_periodic_job_domain
import glot_backend/domain/admin/get_periodic_jobs_domain
import glot_backend/domain/admin/get_rate_limit_policies_domain
import glot_backend/domain/admin/get_run_log_domain
import glot_backend/domain/admin/get_run_logs_domain
import glot_backend/domain/admin/get_user_domain
import glot_backend/domain/admin/get_users_domain
import glot_backend/domain/admin/update_user_domain
import glot_backend/domain/admin/update_periodic_job_domain
import glot_backend/domain/admin/upsert_auth_config_domain
import glot_backend/domain/admin/upsert_cleanup_config_domain
import glot_backend/domain/admin/upsert_debug_config_domain
import glot_backend/domain/admin/upsert_docker_run_config_domain
import glot_backend/domain/admin/upsert_rate_limit_policy_domain
import glot_backend/domain/auth/get_session_domain
import glot_backend/domain/auth/login_domain
import glot_backend/domain/auth/logout_domain
import glot_backend/domain/auth/send_login_token_domain
import glot_backend/domain/navigation/track_pageview_domain
import glot_backend/domain/run_code/get_language_version_domain
import glot_backend/domain/run_code/run_domain
import glot_backend/domain/snippet/create_snippet_domain
import glot_backend/domain/snippet/delete_snippet_domain
import glot_backend/domain/snippet/get_snippet_domain
import glot_backend/domain/snippet/list_public_snippets_domain
import glot_backend/domain/snippet/list_session_snippets_domain
import glot_backend/domain/snippet/update_snippet_domain
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/interpreter
import glot_backend/effect/program
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/server_timing
import glot_backend/worker/app_config_cache_worker
import glot_backend/worker/language_version_cache_worker
import glot_backend/worker/log_worker
import glot_core/admin/api_log_dto
import glot_core/admin/auth_config_dto
import glot_core/admin/cleanup_config_dto
import glot_core/admin/debug_config_dto
import glot_core/admin/docker_run_config_dto
import glot_core/admin/job_dto
import glot_core/admin/job_log_dto
import glot_core/admin/periodic_job_dto
import glot_core/admin/rate_limit_config_dto
import glot_core/admin/run_log_dto
import glot_core/admin/user_dto
import glot_core/api_action
import glot_core/auth/account_dto
import glot_core/auth/account_model
import glot_core/auth/session_dto
import glot_core/run
import glot_core/snippet/snippet_dto
import pog
import wisp

pub fn handle_request(
  db: pog.Connection,
  ctx: context.Context,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
  log_worker_subject: process.Subject(log_worker.Message),
  req: wisp.Request,
) -> wisp.Response {
  use api_request <- require_api_request(req)
  let effect_runtime =
    runtime.new(db, app_config_cache_subject, language_version_cache_subject)

  let #(api_result, state) =
    handle_api_request(ctx, api_request)
    |> interpreter.run(effect_runtime, ctx)

  let total_duration_ns = erlang.perf_counter_ns() - ctx.started_at
  insert_log_entry(
    ctx,
    log_worker_subject,
    state,
    api_request,
    total_duration_ns,
    api_result,
  )
  result_to_response(
    ctx,
    req,
    state.effect_measurements,
    total_duration_ns,
    api_result,
  )
}

fn handle_api_request(
  ctx: context.Context,
  api_request: ApiRequest,
) -> program_types.Program(ApiResult) {
  case api_request.action {
    api_action.TrackPageviewAction -> {
      use request <- program.and_then(
        track_pageview_domain.request_from_dynamic(api_request.data),
      )
      track_pageview_domain.track_pageview(ctx, request)
      |> program.map(TrackPageviewResponse)
    }
    api_action.RunAction -> {
      use request <- program.and_then(run_domain.request_from_dynamic(
        api_request.data,
      ))
      run_domain.run(ctx, request)
      |> program.map(RunResultResponse)
    }
    api_action.GetLanguageVersionAction -> {
      use request <- program.and_then(
        get_language_version_domain.request_from_dynamic(api_request.data),
      )
      get_language_version_domain.get_language_version(ctx, request)
      |> program.map(RunResultResponse)
    }
    api_action.GetSessionAction -> {
      get_session_domain.get_session(ctx)
      |> program.map(SessionResponse)
    }
    api_action.LogoutAction ->
      logout_domain.logout(ctx)
      |> program.map(fn(_) { LogoutResponse })
    api_action.GetAccountAction -> {
      get_account_domain.get_account(ctx)
      |> program.map(AccountResponse)
    }
    api_action.UpdateAccountAction -> {
      use request <- program.and_then(
        update_account_domain.request_from_dynamic(api_request.data),
      )
      update_account_domain.update_account(ctx, request)
      |> program.map(AccountResponse)
    }
    api_action.ScheduleDeleteAccountAction ->
      schedule_delete_account_domain.schedule_delete_account(ctx)
      |> program.map(fn(_) { NoContentResponse })
    api_action.CancelDeleteAccountAction ->
      cancel_delete_account_domain.cancel_delete_account(ctx)
      |> program.map(fn(_) { NoContentResponse })
    api_action.GetSnippetAction -> {
      use request <- program.and_then(get_snippet_domain.request_from_dynamic(
        api_request.data,
      ))
      get_snippet_domain.get_snippet(ctx, request)
      |> program.map(SnippetResponse)
    }
    api_action.ListPublicSnippetsAction -> {
      use request <- program.and_then(
        list_public_snippets_domain.request_from_dynamic(api_request.data),
      )
      list_public_snippets_domain.list_public_snippets(ctx, request)
      |> program.map(SnippetsResponse)
    }
    api_action.ListSessionSnippetsAction -> {
      use request <- program.and_then(
        list_session_snippets_domain.request_from_dynamic(api_request.data),
      )
      list_session_snippets_domain.list_session_snippets(ctx, request)
      |> program.map(SnippetsResponse)
    }
    api_action.CreateSnippetAction -> {
      use request <- program.and_then(
        create_snippet_domain.request_from_dynamic(api_request.data),
      )
      create_snippet_domain.create_snippet(ctx, request)
      |> program.map(SnippetResponse)
    }
    api_action.UpdateSnippetAction -> {
      use request <- program.and_then(
        update_snippet_domain.request_from_dynamic(api_request.data),
      )
      update_snippet_domain.update_snippet(ctx, request)
      |> program.map(SnippetResponse)
    }
    api_action.DeleteSnippetAction -> {
      use request <- program.and_then(
        delete_snippet_domain.request_from_dynamic(api_request.data),
      )
      delete_snippet_domain.delete_snippet(ctx, request)
      |> program.map(fn(_) { NoContentResponse })
    }
    api_action.SendLoginTokenAction -> {
      use request <- program.and_then(
        send_login_token_domain.request_from_dynamic(ctx, api_request.data),
      )
      send_login_token_domain.send_login_token(ctx, request)
      |> program.map(fn(_) { NoContentResponse })
    }
    api_action.LoginAction -> {
      use request <- program.and_then(login_domain.request_from_dynamic(
        ctx,
        api_request.data,
      ))
      login_domain.login(ctx, request)
      |> program.map(LoginResponse)
    }
    api_action.GetAdminDebugConfigAction ->
      get_debug_config_domain.get_debug_config(ctx)
      |> program.map(DebugConfigResponse)
    api_action.UpsertAdminDebugConfigAction -> {
      use request <- program.and_then(
        upsert_debug_config_domain.request_from_dynamic(api_request.data),
      )
      upsert_debug_config_domain.upsert_debug_config(ctx, request)
      |> program.map(DebugConfigResponse)
    }
    api_action.GetAdminAuthConfigAction ->
      get_auth_config_domain.get_auth_config(ctx)
      |> program.map(AuthConfigResponse)
    api_action.UpsertAdminAuthConfigAction -> {
      use request <- program.and_then(
        upsert_auth_config_domain.request_from_dynamic(api_request.data),
      )
      upsert_auth_config_domain.upsert_auth_config(ctx, request)
      |> program.map(AuthConfigResponse)
    }
    api_action.GetAdminCleanupConfigAction ->
      get_cleanup_config_domain.get_cleanup_config(ctx)
      |> program.map(CleanupConfigResponse)
    api_action.UpsertAdminCleanupConfigAction -> {
      use request <- program.and_then(
        upsert_cleanup_config_domain.request_from_dynamic(api_request.data),
      )
      upsert_cleanup_config_domain.upsert_cleanup_config(ctx, request)
      |> program.map(CleanupConfigResponse)
    }
    api_action.GetAdminPeriodicJobsAction ->
      get_periodic_jobs_domain.get_periodic_jobs(ctx)
      |> program.map(AdminPeriodicJobsResponse)
    api_action.GetAdminPeriodicJobAction -> {
      use request <- program.and_then(
        get_periodic_job_domain.request_from_dynamic(api_request.data),
      )
      get_periodic_job_domain.get_periodic_job(ctx, request)
      |> program.map(AdminPeriodicJobDetailResponse)
    }
    api_action.UpdateAdminPeriodicJobAction -> {
      use request <- program.and_then(
        update_periodic_job_domain.request_from_dynamic(api_request.data),
      )
      update_periodic_job_domain.update_periodic_job(ctx, request)
      |> program.map(AdminPeriodicJobResponse)
    }
    api_action.GetAdminJobsAction -> {
      use request <- program.and_then(get_jobs_domain.request_from_dynamic(
        api_request.data,
      ))
      get_jobs_domain.get_jobs(ctx, request)
      |> program.map(AdminJobsResponse)
    }
    api_action.GetAdminJobAction -> {
      use request <- program.and_then(get_job_domain.request_from_dynamic(
        api_request.data,
      ))
      get_job_domain.get_job(ctx, request)
      |> program.map(AdminJobResponse)
    }
    api_action.CreateAdminJobAction -> {
      use request <- program.and_then(create_job_domain.request_from_dynamic(
        api_request.data,
      ))
      create_job_domain.create_job(ctx, request)
      |> program.map(AdminJobResponse)
    }
    api_action.GetAdminUsersAction -> {
      use request <- program.and_then(get_users_domain.request_from_dynamic(
        api_request.data,
      ))
      get_users_domain.get_users(ctx, request)
      |> program.map(AdminUsersResponse)
    }
    api_action.GetAdminUserAction -> {
      use request <- program.and_then(get_user_domain.request_from_dynamic(
        api_request.data,
      ))
      get_user_domain.get_user(ctx, request)
      |> program.map(AdminUserDetailResponse)
    }
    api_action.UpdateAdminUserAction -> {
      use request <- program.and_then(update_user_domain.request_from_dynamic(
        api_request.data,
      ))
      update_user_domain.update_user(ctx, request)
      |> program.map(AdminUserResponse)
    }
    api_action.GetAdminApiLogsAction -> {
      use request <- program.and_then(get_api_logs_domain.request_from_dynamic(
        api_request.data,
      ))
      get_api_logs_domain.get_api_logs(ctx, request)
      |> program.map(AdminApiLogsResponse)
    }
    api_action.GetAdminApiLogAction -> {
      use request <- program.and_then(get_api_log_domain.request_from_dynamic(
        api_request.data,
      ))
      get_api_log_domain.get_api_log(ctx, request)
      |> program.map(AdminApiLogResponse)
    }
    api_action.GetAdminRunLogsAction -> {
      use request <- program.and_then(get_run_logs_domain.request_from_dynamic(
        api_request.data,
      ))
      get_run_logs_domain.get_run_logs(ctx, request)
      |> program.map(AdminRunLogsResponse)
    }
    api_action.GetAdminRunLogAction -> {
      use request <- program.and_then(get_run_log_domain.request_from_dynamic(
        api_request.data,
      ))
      get_run_log_domain.get_run_log(ctx, request)
      |> program.map(AdminRunLogResponse)
    }
    api_action.GetAdminJobLogsAction -> {
      use request <- program.and_then(get_job_logs_domain.request_from_dynamic(
        api_request.data,
      ))
      get_job_logs_domain.get_job_logs(ctx, request)
      |> program.map(AdminJobLogsResponse)
    }
    api_action.GetAdminJobLogAction -> {
      use request <- program.and_then(get_job_log_domain.request_from_dynamic(
        api_request.data,
      ))
      get_job_log_domain.get_job_log(ctx, request)
      |> program.map(AdminJobLogResponse)
    }
    api_action.GetAdminRateLimitPoliciesAction ->
      get_rate_limit_policies_domain.get_rate_limit_policies(ctx)
      |> program.map(RateLimitPoliciesResponse)
    api_action.UpsertAdminRateLimitPolicyAction -> {
      use request <- program.and_then(
        upsert_rate_limit_policy_domain.request_from_dynamic(api_request.data),
      )
      upsert_rate_limit_policy_domain.upsert_rate_limit_policy(ctx, request)
      |> program.map(RateLimitPolicyResponse)
    }
    api_action.GetAdminDockerRunConfigAction ->
      get_docker_run_config_domain.get_docker_run_config(ctx)
      |> program.map(DockerRunConfigResponse)
    api_action.UpsertAdminDockerRunConfigAction -> {
      use request <- program.and_then(
        upsert_docker_run_config_domain.request_from_dynamic(api_request.data),
      )
      upsert_docker_run_config_domain.upsert_docker_run_config(ctx, request)
      |> program.map(DockerRunConfigResponse)
    }
  }
}

pub type ApiRequest {
  ApiRequest(action: api_action.ApiAction, data: dynamic.Dynamic, bytes: Int)
}

pub fn api_request_decoder(bytes: Int) -> decode.Decoder(ApiRequest) {
  use action <- decode.field("action", api_action.decoder())
  use data <- decode.field("data", decode.dynamic)
  decode.success(ApiRequest(action:, data:, bytes:))
}

fn require_api_request(
  request: wisp.Request,
  next: fn(ApiRequest) -> wisp.Response,
) -> wisp.Response {
  case wisp.read_body_bits(request) {
    Ok(bits) ->
      case bit_array.to_string(bits) {
        Ok(body) ->
          case
            json.parse(body, api_request_decoder(bit_array.byte_size(bits)))
          {
            Ok(api_request) -> next(api_request)
            Error(decode_errors) ->
              error_response(
                400,
                "invalid_api_request",
                "Failed to decode as api request: "
                  <> string.inspect(decode_errors),
              )
          }
        Error(_) ->
          error_response(400, "invalid_utf8", "Request body is not valid UTF-8")
      }
    Error(_) ->
      error_response(400, "body_read_error", "Failed to read request body")
  }
}

type ApiResult {
  TrackPageviewResponse(track_pageview_domain.TrackedPageview)
  RunResultResponse(run.RunResult)
  SessionResponse(option.Option(session_dto.SessionResponse))
  AccountResponse(account_dto.AccountResponse)
  SnippetResponse(snippet_dto.SnippetResponse)
  SnippetsResponse(snippet_dto.ListSnippetsResponse)
  DebugConfigResponse(debug_config_dto.DebugConfigResponse)
  AuthConfigResponse(auth_config_dto.AuthConfigResponse)
  CleanupConfigResponse(cleanup_config_dto.CleanupConfigResponse)
  AdminPeriodicJobsResponse(periodic_job_dto.ListPeriodicJobsResponse)
  AdminPeriodicJobDetailResponse(periodic_job_dto.GetPeriodicJobResponse)
  AdminPeriodicJobResponse(periodic_job_dto.UpdatePeriodicJobResponse)
  AdminJobsResponse(job_dto.ListJobsResponse)
  AdminJobResponse(job_dto.GetJobResponse)
  AdminUsersResponse(user_dto.ListUsersResponse)
  AdminUserDetailResponse(user_dto.GetUserResponse)
  AdminUserResponse(user_dto.UpdateUserResponse)
  AdminApiLogsResponse(api_log_dto.ListApiLogsResponse)
  AdminApiLogResponse(api_log_dto.GetApiLogResponse)
  AdminRunLogsResponse(run_log_dto.ListRunLogsResponse)
  AdminRunLogResponse(run_log_dto.GetRunLogResponse)
  AdminJobLogsResponse(job_log_dto.ListJobLogsResponse)
  AdminJobLogResponse(job_log_dto.GetJobLogResponse)
  RateLimitPoliciesResponse(rate_limit_config_dto.RateLimitPoliciesResponse)
  RateLimitPolicyResponse(rate_limit_config_dto.RateLimitPolicyResponse)
  DockerRunConfigResponse(docker_run_config_dto.DockerRunConfigResponse)
  LoginResponse(login_domain.LoginResult)
  LogoutResponse
  NoContentResponse
}

fn api_result_to_response(
  _ctx: context.Context,
  req: wisp.Request,
  result: ApiResult,
) -> wisp.Response {
  case result {
    TrackPageviewResponse(_) -> success_response(json.null())
    RunResultResponse(run_result) -> {
      success_response(run.encode_run_result(run_result))
    }
    SessionResponse(response) ->
      success_response(json.nullable(response, session_dto.encode))
    AccountResponse(response) -> success_response(account_dto.encode(response))
    SnippetResponse(response) ->
      success_response(snippet_dto.encode_response(response))
    SnippetsResponse(response) ->
      success_response(snippet_dto.encode_list_response(response))
    DebugConfigResponse(response) ->
      success_response(debug_config_dto.encode_response(response))
    AuthConfigResponse(response) ->
      success_response(auth_config_dto.encode_response(response))
    CleanupConfigResponse(response) ->
      success_response(cleanup_config_dto.encode_response(response))
    AdminPeriodicJobsResponse(response) ->
      success_response(periodic_job_dto.encode_list_response(response))
    AdminPeriodicJobDetailResponse(response) ->
      success_response(periodic_job_dto.encode_get_response(response))
    AdminPeriodicJobResponse(response) ->
      success_response(periodic_job_dto.encode_update_response(response))
    AdminJobsResponse(response) ->
      success_response(job_dto.encode_list_response(response))
    AdminJobResponse(response) ->
      success_response(job_dto.encode_get_response(response))
    AdminUsersResponse(response) ->
      success_response(user_dto.encode_list_response(response))
    AdminUserDetailResponse(response) ->
      success_response(user_dto.encode_get_response(response))
    AdminUserResponse(response) ->
      success_response(user_dto.encode_update_response(response))
    AdminApiLogsResponse(response) ->
      success_response(api_log_dto.encode_list_response(response))
    AdminApiLogResponse(response) ->
      success_response(api_log_dto.encode_get_response(response))
    AdminRunLogsResponse(response) ->
      success_response(run_log_dto.encode_list_response(response))
    AdminRunLogResponse(response) ->
      success_response(run_log_dto.encode_get_response(response))
    AdminJobLogsResponse(response) ->
      success_response(job_log_dto.encode_list_response(response))
    AdminJobLogResponse(response) ->
      success_response(job_log_dto.encode_get_response(response))
    RateLimitPoliciesResponse(response) ->
      success_response(rate_limit_config_dto.encode_response(response))
    RateLimitPolicyResponse(response) ->
      success_response(rate_limit_config_dto.encode_policy_response(response))
    DockerRunConfigResponse(response) ->
      success_response(docker_run_config_dto.encode_response(response))
    LoginResponse(login_result) -> {
      success_response(json.null())
      |> wisp.set_cookie(
        request: req,
        name: "session",
        value: login_result.session_token,
        security: wisp.Signed,
        max_age: login_result.session_cookie_max_age,
      )
    }
    LogoutResponse -> {
      success_response(json.null())
      |> wisp.set_cookie(
        request: req,
        name: "session",
        value: "",
        security: wisp.Signed,
        max_age: 0,
      )
    }
    NoContentResponse -> success_response(json.null())
  }
}

fn success_response(data: json.Json) -> wisp.Response {
  wisp.json_response(json.to_string(json.object([#("data", data)])), 200)
}

fn error_response(status: Int, code: String, message: String) -> wisp.Response {
  wisp.json_response(
    json.to_string(
      json.object([
        #(
          "error",
          json.object([
            #("code", json.string(code)),
            #("message", json.string(message)),
          ]),
        ),
      ]),
    ),
    status,
  )
}

fn insert_log_entry(
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
  state: program_state.State,
  api_request: ApiRequest,
  total_duration_ns: Int,
  result: Result(ApiResult, error.Error),
) -> Nil {
  let error = case result {
    Ok(_) -> option.None
    Error(err) -> option.Some(err)
  }

  case process.subject_owner(log_worker_subject) {
    Ok(_) -> {
      process.send(
        log_worker_subject,
        log_worker.Insert(prepare_log_entry(
          ctx,
          state,
          api_request,
          total_duration_ns,
          error,
        )),
      )
      insert_pageview_log_entry(ctx, log_worker_subject, result)
      Nil
    }
    Error(_) -> wisp.log_error("Log worker unavailable")
  }
}

fn insert_pageview_log_entry(
  ctx: context.Context,
  log_worker_subject: process.Subject(log_worker.Message),
  result: Result(ApiResult, error.Error),
) -> Nil {
  case result {
    Ok(TrackPageviewResponse(pageview)) ->
      process.send(
        log_worker_subject,
        log_worker.InsertPageview(log_worker.PageviewLogEntry(
          id: pageview.id,
          created_at: ctx.timestamp,
          session_id: pageview.session_id,
          user_id: pageview.user_id,
          route: pageview.route,
          path: pageview.path,
          user_agent: ctx.client_info.user_agent,
          ip: ctx.client_info.ip,
        )),
      )
    Ok(_) | Error(_) -> Nil
  }
}

fn prepare_log_entry(
  ctx: context.Context,
  state: program_state.State,
  api_request: ApiRequest,
  total_duration_ns: Int,
  error: option.Option(error.Error),
) -> log_worker.ApiLogEntry {
  let id = basic_handlers.uuid_v7(ctx.timestamp)

  log_worker.ApiLogEntry(
    id: id,
    request_id: ctx.request_id,
    created_at: ctx.timestamp,
    action: api_request.action,
    body_bytes: api_request.bytes,
    duration_ns: total_duration_ns,
    ip: ctx.client_info.ip,
    user_agent: ctx.client_info.user_agent,
    info: state.info_fields,
    warnings: state.warning_fields,
    debug: state.debug_fields,
    error: error,
    effects: state.effect_measurements,
  )
}

fn result_to_response(
  ctx: context.Context,
  request: wisp.Request,
  effects: List(effect_trace.EffectMeasurement),
  total_duration_ns: Int,
  result: Result(ApiResult, error.Error),
) -> wisp.Response {
  case result {
    Ok(response) ->
      api_result_to_response(ctx, request, response)
      |> wisp.set_header(
        "Server-Timing",
        server_timing.prepare(effects, total_duration_ns),
      )
    Error(err) -> error_to_response(err)
  }
}

fn error_to_response(error: error.Error) -> wisp.Response {
  let #(status, code, message) = api_error_details(error)

  case error {
    error.JsonParseError(_error) -> error_response(status, code, message)
    error.DecodeError(_errors) -> error_response(status, code, message)
    error.EmailInvalidError(_message) -> error_response(status, code, message)
    error.ValidationError(message) -> {
      wisp.log_error("Validation error: " <> message)
      error_response(status, code, message)
    }
    error.NotFoundError(code, message) -> {
      wisp.log_error("Not found error: " <> code <> ":" <> message)
      error_response(status, code, message)
    }
    error.ConflictError(code, message) -> {
      wisp.log_error("Conflict error: " <> code <> ":" <> message)
      error_response(status, code, message)
    }
    error.TooManyRequestsError(_count, _config) ->
      error_response(status, code, message)
    error.QueryError(error.DbQueryError(message: message)) -> {
      wisp.log_error("Query error: " <> message)
      error_response(status, code, message)
    }
    error.CommandError(error.DbCommandError(message: message)) -> {
      wisp.log_error("Command error: " <> message)
      error_response(status, code, message)
    }
    error.TransactionError(error.DbTransactionError(message: message)) -> {
      wisp.log_error("Transaction error: " <> message)
      error_response(status, code, message)
    }
    error.LoginError(login_error) ->
      case login_error {
        error.InvalidTokenError -> {
          wisp.log_error("Login error: invalid token")
          error_response(status, code, message)
        }
        error.TokenUsedError -> {
          wisp.log_error("Login error: token used")
          error_response(status, code, message)
        }
        error.TokenExpiredError -> {
          wisp.log_error("Login error: token expired")
          error_response(status, code, message)
        }
      }
    error.SendEmailError(send_email_error) ->
      case send_email_error {
        error.PublicSendEmailError(message: message) -> {
          wisp.log_error("Send email error (public): " <> message)
          error_response(status, code, message)
        }
        error.InternalSendEmailError(message: message) -> {
          wisp.log_error("Send email error (private): " <> message)
          error_response(status, code, message)
        }
      }
    error.SessionError(session_error) ->
      case session_error {
        error.MissingSessionTokenError -> {
          wisp.log_error("Session error: missing session token")
          error_response(status, code, message)
        }
        error.SessionNotFoundError -> {
          wisp.log_error("Session error: session not found")
          error_response(status, code, message)
        }
        error.SessionExpiredError -> {
          wisp.log_error("Session error: session expired")
          error_response(status, code, message)
        }
      }
    error.ClientInfoError(client_info_error) ->
      case client_info_error {
        error.MissingUserIdAndIpError -> {
          wisp.log_error("Client info error: missing user_id and ip")
          error_response(status, code, message)
        }
      }
    error.AuthorizationError(authorization_error) ->
      case authorization_error {
        error.NotOwnerError -> {
          wisp.log_error("Authorization error: not owner")
          error_response(status, code, message)
        }
        error.AdminRequiredError -> {
          wisp.log_error("Authorization error: admin required")
          error_response(status, code, message)
        }
      }
    error.AccountStateError(account_state_error) ->
      case account_state_error {
        error.ForbiddenAccountState(
          action: action,
          account_state: account_state,
        ) -> {
          wisp.log_error(
            "Account state error: "
            <> account_model.account_state_to_string(account_state)
            <> " not allowed for "
            <> api_action.to_string(action),
          )
          error_response(status, code, message)
        }
      }
    error.RunError(run_request_error) ->
      case run_request_error {
        error.PublicRunRequestError(message: message) -> {
          wisp.log_error("Run request error (public): " <> message)
          error_response(status, code, message)
        }
        error.InternalRunRequestError(message: message) -> {
          wisp.log_error("Run request error (private): " <> message)
          error_response(status, code, message)
        }
      }
  }
}

pub fn error_status(error: error.Error) -> Int {
  let #(status, _, _) = api_error_details(error)
  status
}

pub fn api_error_details(error: error.Error) -> #(Int, String, String) {
  case error {
    error.JsonParseError(parse_error) -> #(
      400,
      "json_parse_error",
      "Decode error: " <> string.inspect(parse_error),
    )
    error.DecodeError(errors) -> #(
      400,
      "decode_error",
      "Decode error: " <> string.inspect(errors),
    )
    error.EmailInvalidError(message) -> #(
      400,
      "email_invalid",
      "Invalid email: " <> message,
    )
    error.ValidationError(message) -> #(
      400,
      validation_error_code(message),
      message,
    )
    error.NotFoundError(code, message) -> #(404, code, message)
    error.ConflictError(code, message) -> #(409, code, message)
    error.TooManyRequestsError(count, config) -> #(
      429,
      "too_many_requests",
      "Too many requests: "
        <> int.to_string(count)
        <> " / "
        <> int.to_string(config.max_requests),
    )
    error.QueryError(_) -> #(500, "query_error", "Failed to query data")
    error.CommandError(_) -> #(500, "command_error", "Failed to run command")
    error.TransactionError(_) -> #(
      500,
      "transaction_error",
      "Transaction failed",
    )
    error.ClientInfoError(_) -> #(
      500,
      "client_info_error",
      "Missing user_id and ip",
    )
    error.LoginError(login_error) ->
      case login_error {
        error.InvalidTokenError -> #(
          401,
          "login_invalid_token",
          "Invalid login token",
        )
        error.TokenUsedError -> #(
          409,
          "login_token_used",
          "Login token already used",
        )
        error.TokenExpiredError -> #(
          401,
          "login_token_expired",
          "Login token expired",
        )
      }
    error.SendEmailError(send_email_error) ->
      case send_email_error {
        error.PublicSendEmailError(message: message) -> #(
          400,
          "send_email_public_error",
          message,
        )
        error.InternalSendEmailError(message: _) -> #(
          500,
          "send_email_internal_error",
          "Failed to send email",
        )
      }
    error.SessionError(session_error) ->
      case session_error {
        error.MissingSessionTokenError -> #(
          401,
          "session_missing_token",
          "Missing session token",
        )
        error.SessionNotFoundError -> #(
          401,
          "session_not_found",
          "Session not found",
        )
        error.SessionExpiredError -> #(
          401,
          "session_expired",
          "Session expired",
        )
      }
    error.AuthorizationError(authorization_error) ->
      case authorization_error {
        error.NotOwnerError -> #(
          403,
          "authorization_not_owner",
          "Not authorized",
        )
        error.AdminRequiredError -> #(
          403,
          "authorization_admin_required",
          "Admin access required",
        )
      }
    error.AccountStateError(_) -> #(
      403,
      "account_state_forbidden",
      "Account state not allowed",
    )
    error.RunError(run_request_error) ->
      case run_request_error {
        error.PublicRunRequestError(message: message) -> #(
          400,
          "run_public_error",
          message,
        )
        error.InternalRunRequestError(message: _) -> #(
          500,
          "run_internal_error",
          "Failed to run code",
        )
      }
  }
}

fn validation_error_code(message: String) -> String {
  case message {
    "files must contain at least one file" -> "validation_files_missing"
    _ ->
      case string.split_once(message, " must not be empty") {
        Ok(#(field, "")) ->
          "validation_" <> validation_field_slug(field) <> "_empty"
        Ok(#(_, _)) ->
          case is_spam_validation_message(message) {
            True -> "validation_spam_detected"
            False -> "validation_error"
          }
        Error(_) ->
          case string.split_once(message, " must be at most ") {
            Ok(#(field, rest)) ->
              case string.ends_with(rest, " characters") {
                True ->
                  "validation_" <> validation_field_slug(field) <> "_too_long"
                False ->
                  case is_spam_validation_message(message) {
                    True -> "validation_spam_detected"
                    False -> "validation_error"
                  }
              }
            _ ->
              case is_spam_validation_message(message) {
                True -> "validation_spam_detected"
                False -> "validation_error"
              }
          }
      }
  }
}

fn is_spam_validation_message(message: String) -> Bool {
  string.contains(message, " contains multiple links")
  || string.contains(message, " matched spam phrases: ")
  || string.contains(message, " contains hidden characters")
  || message == "suspicious filename combined with links"
}

fn validation_field_slug(field: String) -> String {
  field
  |> string.lowercase
  |> string.replace(each: ".", with: "_")
  |> string.replace(each: "[", with: "_")
  |> string.replace(each: "]", with: "")
  |> string.to_graphemes
  |> list.filter(fn(part) { part != "" })
  |> list.fold("", fn(acc, part) {
    case part, acc {
      "_", "" -> acc
      "_", acc ->
        case string.ends_with(acc, "_") {
          True -> acc
          False -> acc <> "_"
        }
      part, acc -> acc <> part
    }
  })
}
