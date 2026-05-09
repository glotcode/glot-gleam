import gleam/dynamic/decode
import gleam/json

pub type CleanupConfigResponse {
  CleanupConfigResponse(
    api_log_retention_days: Int,
    page_log_retention_days: Int,
    pageview_log_retention_days: Int,
    run_log_retention_days: Int,
    job_log_retention_days: Int,
    jobs_retention_days: Int,
    login_tokens_retention_days: Int,
    user_actions_retention_days: Int,
  )
}

pub type UpsertCleanupConfigRequest {
  UpsertCleanupConfigRequest(
    api_log_retention_days: Int,
    page_log_retention_days: Int,
    pageview_log_retention_days: Int,
    run_log_retention_days: Int,
    job_log_retention_days: Int,
    jobs_retention_days: Int,
    login_tokens_retention_days: Int,
    user_actions_retention_days: Int,
  )
}

pub fn response_decoder() -> decode.Decoder(CleanupConfigResponse) {
  use api_log_retention_days <- decode.field("apiLogRetentionDays", decode.int)
  use page_log_retention_days <- decode.field(
    "pageLogRetentionDays",
    decode.int,
  )
  use pageview_log_retention_days <- decode.field(
    "pageviewLogRetentionDays",
    decode.int,
  )
  use run_log_retention_days <- decode.field("runLogRetentionDays", decode.int)
  use job_log_retention_days <- decode.field("jobLogRetentionDays", decode.int)
  use jobs_retention_days <- decode.field("jobsRetentionDays", decode.int)
  use login_tokens_retention_days <- decode.field(
    "loginTokensRetentionDays",
    decode.int,
  )
  use user_actions_retention_days <- decode.field(
    "userActionsRetentionDays",
    decode.int,
  )
  decode.success(CleanupConfigResponse(
    api_log_retention_days: api_log_retention_days,
    page_log_retention_days: page_log_retention_days,
    pageview_log_retention_days: pageview_log_retention_days,
    run_log_retention_days: run_log_retention_days,
    job_log_retention_days: job_log_retention_days,
    jobs_retention_days: jobs_retention_days,
    login_tokens_retention_days: login_tokens_retention_days,
    user_actions_retention_days: user_actions_retention_days,
  ))
}

pub fn decoder() -> decode.Decoder(UpsertCleanupConfigRequest) {
  use api_log_retention_days <- decode.field("apiLogRetentionDays", decode.int)
  use page_log_retention_days <- decode.field(
    "pageLogRetentionDays",
    decode.int,
  )
  use pageview_log_retention_days <- decode.field(
    "pageviewLogRetentionDays",
    decode.int,
  )
  use run_log_retention_days <- decode.field("runLogRetentionDays", decode.int)
  use job_log_retention_days <- decode.field("jobLogRetentionDays", decode.int)
  use jobs_retention_days <- decode.field("jobsRetentionDays", decode.int)
  use login_tokens_retention_days <- decode.field(
    "loginTokensRetentionDays",
    decode.int,
  )
  use user_actions_retention_days <- decode.field(
    "userActionsRetentionDays",
    decode.int,
  )
  decode.success(UpsertCleanupConfigRequest(
    api_log_retention_days: api_log_retention_days,
    page_log_retention_days: page_log_retention_days,
    pageview_log_retention_days: pageview_log_retention_days,
    run_log_retention_days: run_log_retention_days,
    job_log_retention_days: job_log_retention_days,
    jobs_retention_days: jobs_retention_days,
    login_tokens_retention_days: login_tokens_retention_days,
    user_actions_retention_days: user_actions_retention_days,
  ))
}

pub fn encode_response(response: CleanupConfigResponse) -> json.Json {
  json.object([
    #("apiLogRetentionDays", json.int(response.api_log_retention_days)),
    #("pageLogRetentionDays", json.int(response.page_log_retention_days)),
    #(
      "pageviewLogRetentionDays",
      json.int(response.pageview_log_retention_days),
    ),
    #("runLogRetentionDays", json.int(response.run_log_retention_days)),
    #("jobLogRetentionDays", json.int(response.job_log_retention_days)),
    #("jobsRetentionDays", json.int(response.jobs_retention_days)),
    #(
      "loginTokensRetentionDays",
      json.int(response.login_tokens_retention_days),
    ),
    #(
      "userActionsRetentionDays",
      json.int(response.user_actions_retention_days),
    ),
  ])
}

pub fn encode_request(request: UpsertCleanupConfigRequest) -> json.Json {
  json.object([
    #("apiLogRetentionDays", json.int(request.api_log_retention_days)),
    #("pageLogRetentionDays", json.int(request.page_log_retention_days)),
    #("pageviewLogRetentionDays", json.int(request.pageview_log_retention_days)),
    #("runLogRetentionDays", json.int(request.run_log_retention_days)),
    #("jobLogRetentionDays", json.int(request.job_log_retention_days)),
    #("jobsRetentionDays", json.int(request.jobs_retention_days)),
    #("loginTokensRetentionDays", json.int(request.login_tokens_retention_days)),
    #("userActionsRetentionDays", json.int(request.user_actions_retention_days)),
  ])
}
