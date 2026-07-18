import gleam/json
import gleam/list
import gleam/option.{type Option}
import glot_backend/cache_outcome.{type CacheOutcome}
import glot_backend/effect/admin_log/admin_log_algebra
import glot_backend/effect/analytics/analytics_algebra
import glot_backend/effect/api_log/api_log_algebra
import glot_backend/effect/app_config/app_config_algebra
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/email/email_algebra
import glot_backend/effect/email_template/email_template_algebra
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/job/job_algebra
import glot_backend/effect/job_log/job_log_algebra
import glot_backend/effect/job_type_policy/job_type_policy_algebra
import glot_backend/effect/page_log/page_log_algebra
import glot_backend/effect/pageview_log/pageview_log_algebra
import glot_backend/effect/periodic_job/periodic_job_algebra
import glot_backend/effect/run_log/run_log_algebra
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/effect/transaction/transaction_algebra
import glot_backend/effect/user_action/user_action_algebra
import glot_backend/effect/webauthn/webauthn_algebra

pub type EffectName {
  AppConfigEffectName(app_config_algebra.EffectName)
  AdminLogEffectName(admin_log_algebra.EffectName)
  ApiLogEffectName(api_log_algebra.EffectName)
  AnalyticsEffectName(analytics_algebra.EffectName)
  BasicEffectName(basic_algebra.EffectName)
  EmailEffectName(email_algebra.EffectName)
  WebauthnEffectName(webauthn_algebra.EffectName)
  EmailTemplateEffectName(email_template_algebra.EffectName)
  JobEffectName(job_algebra.EffectName)
  JobLogEffectName(job_log_algebra.EffectName)
  JobTypePolicyEffectName(job_type_policy_algebra.EffectName)
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
    WebauthnEffectName(name) -> webauthn_algebra.effect_name_to_string(name)
    EmailTemplateEffectName(name) ->
      email_template_algebra.effect_name_to_string(name)
    JobEffectName(name) -> job_algebra.effect_name_to_string(name)
    JobLogEffectName(name) -> job_log_algebra.effect_name_to_string(name)
    JobTypePolicyEffectName(name) ->
      job_type_policy_algebra.effect_name_to_string(name)
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
    WebauthnEffectName(_) -> "webauthn"
    EmailTemplateEffectName(_) -> "email_template"
    JobEffectName(_) -> "job"
    JobLogEffectName(_) -> "job_log"
    JobTypePolicyEffectName(_) -> "job_type_policy"
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

pub type EffectKind {
  RuntimeEffect
  LogEffect
  DockerCallEffect
  EmailCallEffect
  CacheReadEffect(CacheOutcome)
  DatabaseReadEffect
  DatabaseWriteEffect
}

pub type EffectCategory {
  RuntimeCategory
  LogCategory
  ReadCategory
  WriteCategory
  ExternalCategory
}

pub type EffectSource {
  DatabaseEffectSource
  CacheEffectSource(CacheOutcome)
  DockerEffectSource
  EmailEffectSource
}

pub fn effect_kind_details(
  kind: EffectKind,
) -> #(EffectCategory, Option(EffectSource)) {
  case kind {
    RuntimeEffect -> #(RuntimeCategory, option.None)
    LogEffect -> #(LogCategory, option.None)
    DockerCallEffect -> #(ExternalCategory, option.Some(DockerEffectSource))
    EmailCallEffect -> #(ExternalCategory, option.Some(EmailEffectSource))
    CacheReadEffect(outcome) -> #(
      ReadCategory,
      option.Some(CacheEffectSource(outcome)),
    )
    DatabaseReadEffect -> #(ReadCategory, option.Some(DatabaseEffectSource))
    DatabaseWriteEffect -> #(WriteCategory, option.Some(DatabaseEffectSource))
  }
}

pub fn effect_category_to_string(category: EffectCategory) -> String {
  case category {
    RuntimeCategory -> "runtime"
    LogCategory -> "log"
    ReadCategory -> "read"
    WriteCategory -> "write"
    ExternalCategory -> "external"
  }
}

pub fn effect_source_to_string(source: EffectSource) -> String {
  case source {
    DatabaseEffectSource -> "database"
    CacheEffectSource(_) -> "cache"
    DockerEffectSource -> "docker"
    EmailEffectSource -> "email"
  }
}

pub type EffectMeasurement {
  EffectMeasurement(
    name: EffectName,
    category: EffectCategory,
    source: Option(EffectSource),
    duration_ns: Int,
  )
}

pub fn encode_effect_measurements(
  effects: List(EffectMeasurement),
) -> json.Json {
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
  let source = option.map(effect_measurement.source, effect_source_to_string)
  let cache_outcome = case effect_measurement.source {
    option.Some(CacheEffectSource(outcome)) ->
      option.Some(cache_outcome.to_string(outcome))
    _ -> option.None
  }
  let common_fields = [
    #("category", json.string(effect_category)),
    #("family", json.string(effect_name_to_family(effect_name))),
    #("name", json.string(effect_name_to_string(effect_name))),
    #("source", json.nullable(source, json.string)),
    #("cache_outcome", json.nullable(cache_outcome, json.string)),
    #("duration_ns", json.int(duration_ns)),
  ]
  case effect_name {
    TransactionEffectName(_, sub_effects, rolled_back:) ->
      json.object(
        list.append(common_fields, [
          #("rolled_back", json.bool(rolled_back)),
          #("effects", json.array(sub_effects, encode_effect_measurement)),
        ]),
      )
    _ -> json.object(common_fields)
  }
}
