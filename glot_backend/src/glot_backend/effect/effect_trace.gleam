import gleam/json
import gleam/list
import glot_backend/effect/admin_log/admin_log_algebra
import glot_backend/effect/analytics/analytics_algebra
import glot_backend/effect/api_log/api_log_algebra
import glot_backend/effect/app_config/app_config_algebra
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/email/email_algebra
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/job/job_algebra
import glot_backend/effect/job_log/job_log_algebra
import glot_backend/effect/page_log/page_log_algebra
import glot_backend/effect/pageview_log/pageview_log_algebra
import glot_backend/effect/periodic_job/periodic_job_algebra
import glot_backend/effect/run_log/run_log_algebra
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/effect/transaction/transaction_algebra
import glot_backend/effect/user_action/user_action_algebra

pub type EffectName {
  AppConfigEffectName(app_config_algebra.EffectName)
  AdminLogEffectName(admin_log_algebra.EffectName)
  ApiLogEffectName(api_log_algebra.EffectName)
  AnalyticsEffectName(analytics_algebra.EffectName)
  BasicEffectName(basic_algebra.EffectName)
  EmailEffectName(email_algebra.EffectName)
  JobEffectName(job_algebra.EffectName)
  JobLogEffectName(job_log_algebra.EffectName)
  PageLogEffectName(page_log_algebra.EffectName)
  PageviewLogEffectName(pageview_log_algebra.EffectName)
  PeriodicJobEffectName(periodic_job_algebra.EffectName)
  RunLogEffectName(run_log_algebra.EffectName)
  AuthEffectName(auth_algebra.EffectName)
  SnippetEffectName(snippet_algebra.EffectName)
  DockerRunEffectName(docker_run_algebra.EffectName)
  GetLanguageVersionEffectName(get_language_version_algebra.EffectName)
  UserActionEffectName(user_action_algebra.EffectName)
  TransactionEffectName(
    transaction_algebra.EffectName,
    List(EffectMeasurement),
    rolled_back: Bool,
  )
}

pub fn effect_name_to_string(effect_name: EffectName) -> String {
  case effect_name {
    AppConfigEffectName(name) -> app_config_algebra.effect_name_to_string(name)
    AdminLogEffectName(name) -> admin_log_algebra.effect_name_to_string(name)
    ApiLogEffectName(name) -> api_log_algebra.effect_name_to_string(name)
    AnalyticsEffectName(name) -> analytics_algebra.effect_name_to_string(name)
    BasicEffectName(name) -> basic_algebra.effect_name_to_string(name)
    EmailEffectName(name) -> email_algebra.effect_name_to_string(name)
    JobEffectName(name) -> job_algebra.effect_name_to_string(name)
    JobLogEffectName(name) -> job_log_algebra.effect_name_to_string(name)
    PageLogEffectName(name) -> page_log_algebra.effect_name_to_string(name)
    PageviewLogEffectName(name) ->
      pageview_log_algebra.effect_name_to_string(name)
    PeriodicJobEffectName(name) ->
      periodic_job_algebra.effect_name_to_string(name)
    RunLogEffectName(name) -> run_log_algebra.effect_name_to_string(name)
    AuthEffectName(name) -> auth_algebra.effect_name_to_string(name)
    SnippetEffectName(name) -> snippet_algebra.effect_name_to_string(name)
    DockerRunEffectName(name) -> docker_run_algebra.effect_name_to_string(name)
    GetLanguageVersionEffectName(name) ->
      get_language_version_algebra.effect_name_to_string(name)
    UserActionEffectName(name) ->
      user_action_algebra.effect_name_to_string(name)
    TransactionEffectName(name, _, _) ->
      transaction_algebra.effect_name_to_string(name)
  }
}

pub fn effect_name_to_family(effect_name: EffectName) -> String {
  case effect_name {
    AppConfigEffectName(_) -> "app_config"
    AdminLogEffectName(_) -> "admin_log"
    ApiLogEffectName(_) -> "api_log"
    AnalyticsEffectName(_) -> "analytics"
    BasicEffectName(_) -> "basic"
    EmailEffectName(_) -> "email"
    JobEffectName(_) -> "job"
    JobLogEffectName(_) -> "job_log"
    PageLogEffectName(_) -> "page_log"
    PageviewLogEffectName(_) -> "pageview_log"
    PeriodicJobEffectName(_) -> "periodic_job"
    RunLogEffectName(_) -> "run_log"
    AuthEffectName(_) -> "auth"
    SnippetEffectName(_) -> "snippet"
    DockerRunEffectName(_) -> "docker_run"
    GetLanguageVersionEffectName(_) -> "get_language_version"
    UserActionEffectName(_) -> "user_action"
    TransactionEffectName(_, _, _) -> "transaction"
  }
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

pub type EffectMeasurement {
  EffectMeasurement(
    name: EffectName,
    category: EffectCategory,
    duration_ns: Int,
  )
}

pub fn encode_effect_measurements(effects: List(EffectMeasurement)) -> json.Json {
  json.object([
    #("effects", json.array(effects, encode_effect_measurement)),
    #(
      "summary",
      json.object([
        #("count", json.int(list.length(effects))),
        #(
          "duration_ns",
          json.int(
            list.fold(effects, 0, fn(acc, effect_measurement) {
              acc + effect_measurement.duration_ns
            }),
          ),
        ),
      ]),
    ),
  ])
}

pub fn encode_effect_measurement(
  effect_measurement: EffectMeasurement,
) -> json.Json {
  let effect_name = effect_measurement.name
  let duration_ns = effect_measurement.duration_ns
  let effect_category = effect_category_to_string(effect_measurement.category)
  case effect_name {
    TransactionEffectName(_, sub_effects, rolled_back:) ->
      json.object([
        #("category", json.string(effect_category)),
        #("family", json.string(effect_name_to_family(effect_name))),
        #("name", json.string(effect_name_to_string(effect_name))),
        #("rolled_back", json.bool(rolled_back)),
        #("effects", json.array(sub_effects, encode_effect_measurement)),
        #("duration_ns", json.int(duration_ns)),
      ])
    _ ->
      json.object([
        #("category", json.string(effect_category)),
        #("family", json.string(effect_name_to_family(effect_name))),
        #("name", json.string(effect_name_to_string(effect_name))),
        #("duration_ns", json.int(duration_ns)),
      ])
  }
}
