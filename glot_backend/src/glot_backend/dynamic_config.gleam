import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import glot_backend/app_config
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/rate_limit

pub type DynamicConfig {
  DynamicConfig(
    auth: option.Option(AuthConfig),
    cleanup: CleanupConfig,
    docker_run: option.Option(DockerRunConfig),
    rate_limit_policies: dict.Dict(api_action.ApiAction, RateLimitPolicy),
  )
}

pub type AuthConfig {
  AuthConfig(
    login_token_max_age: Int,
    session_token_max_age: Int,
    session_cookie_max_age: Int,
  )
}

pub type DockerRunConfig {
  DockerRunConfig(base_url: String, access_token: String)
}

pub type CleanupConfig {
  CleanupConfig(
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

pub type RateLimitPolicy {
  RateLimitPolicy(rules: List(RateLimitRule))
}

pub type RateLimitRule {
  RateLimitRule(match: RateLimitMatch, limits: List(rate_limit.RateLimit))
}

pub type RateLimitMatch {
  AnonymousMatch
  AuthenticatedMatch(
    account_tiers: option.Option(List(account_model.AccountTier)),
  )
}

pub type RateLimitActor {
  AnonymousActor
  AuthenticatedActor(account_tier: account_model.AccountTier)
}

type PartialAuthConfig {
  PartialAuthConfig(
    login_token_max_age: option.Option(Int),
    session_token_max_age: option.Option(Int),
    session_cookie_max_age: option.Option(Int),
  )
}

pub fn empty() -> DynamicConfig {
  DynamicConfig(
    auth: option.None,
    cleanup: default_cleanup_config(),
    docker_run: option.None,
    rate_limit_policies: dict.new(),
  )
}

pub fn from_entries(
  entries: List(app_config.AppConfigEntry),
) -> Result(DynamicConfig, String) {
  use auth <- result.try(auth_config_from_entries(entries))

  list.fold(entries, Ok(DynamicConfig(..empty(), auth: option.Some(auth))), fn(acc, entry) {
    use config <- result.try(acc)
    apply_entry(config, entry)
  })
}

pub fn lookup_rate_limit_policy(
  config: DynamicConfig,
  action: api_action.ApiAction,
) -> option.Option(RateLimitPolicy) {
  dict.get(config.rate_limit_policies, action)
  |> option.from_result()
}

pub fn lookup_docker_run_config(
  config: DynamicConfig,
) -> option.Option(DockerRunConfig) {
  config.docker_run
}

pub fn lookup_auth_config(config: DynamicConfig) -> option.Option(AuthConfig) {
  config.auth
}

pub fn select_rate_limits(
  policy: RateLimitPolicy,
  actor: RateLimitActor,
) -> List(rate_limit.RateLimit) {
  policy.rules
  |> list.fold(option.None, fn(best, rule) {
    case rule_match_priority(rule.match, actor) {
      option.None -> best
      option.Some(priority) ->
        case best {
          option.Some(#(best_priority, _)) if best_priority >= priority -> best
          _ -> option.Some(#(priority, rule.limits))
        }
    }
  })
  |> option.map(fn(selected) {
    let #(_priority, limits) = selected
    limits
  })
  |> option.unwrap([])
}

pub fn list_rate_limit_policies(
  config: DynamicConfig,
) -> List(#(api_action.ApiAction, RateLimitPolicy)) {
  dict.to_list(config.rate_limit_policies)
}

pub fn encode_rate_limit_policy(policy: RateLimitPolicy) -> json.Json {
  json.object([
    #("rules", json.array(policy.rules, encode_rate_limit_rule)),
  ])
}

fn apply_entry(
  config: DynamicConfig,
  entry: app_config.AppConfigEntry,
) -> Result(DynamicConfig, String) {
  case entry.namespace {
    "cleanup" -> decode_cleanup_entry(config, entry)
    "docker_run" -> decode_docker_run_entry(config, entry)
    "rate_limit" -> decode_rate_limit_policy_entry(config, entry)
    _ -> Ok(config)
  }
}

fn auth_config_from_entries(
  entries: List(app_config.AppConfigEntry),
) -> Result(AuthConfig, String) {
  list.fold(entries, Ok(PartialAuthConfig(
    login_token_max_age: option.None,
    session_token_max_age: option.None,
    session_cookie_max_age: option.None,
  )), fn(acc, entry) {
    use partial <- result.try(acc)
    case entry.namespace {
      "auth" -> decode_auth_entry(partial, entry)
      _ -> Ok(partial)
    }
  })
  |> result.try(build_auth_config)
}

fn decode_auth_entry(
  partial: PartialAuthConfig,
  entry: app_config.AppConfigEntry,
) -> Result(PartialAuthConfig, String) {
  use value <- result.try(
    json.parse(entry.value, decode.int)
    |> result.map_error(fn(err) {
      "Failed to decode auth app_config for "
      <> entry.key
      <> ": "
      <> string.inspect(err)
    }),
  )

  Ok(case entry.key {
    "login_token_max_age" ->
      PartialAuthConfig(..partial, login_token_max_age: option.Some(value))
    "session_token_max_age" ->
      PartialAuthConfig(..partial, session_token_max_age: option.Some(value))
    "session_cookie_max_age" ->
      PartialAuthConfig(..partial, session_cookie_max_age: option.Some(value))
    _ -> partial
  })
}

fn build_auth_config(partial: PartialAuthConfig) -> Result(AuthConfig, String) {
  use login_token_max_age <- result.try(option.to_result(
    partial.login_token_max_age,
    "Missing auth app_config entries",
  ))
  use session_token_max_age <- result.try(option.to_result(
    partial.session_token_max_age,
    "Missing auth app_config entries",
  ))
  use session_cookie_max_age <- result.try(option.to_result(
    partial.session_cookie_max_age,
    "Missing auth app_config entries",
  ))

  Ok(AuthConfig(
    login_token_max_age: login_token_max_age,
    session_token_max_age: session_token_max_age,
    session_cookie_max_age: session_cookie_max_age,
  ))
}

pub fn require_auth_config(config: DynamicConfig) -> Result(AuthConfig, String) {
  option.to_result(config.auth, "Missing auth app_config entries")
}

pub fn lookup_cleanup_config(config: DynamicConfig) -> CleanupConfig {
  config.cleanup
}

fn default_cleanup_config() -> CleanupConfig {
  CleanupConfig(
    api_log_retention_days: 30,
    page_log_retention_days: 30,
    pageview_log_retention_days: 30,
    run_log_retention_days: 90,
    job_log_retention_days: 90,
    jobs_retention_days: 90,
    login_tokens_retention_days: 30,
    user_actions_retention_days: 90,
  )
}

fn decode_cleanup_entry(
  config: DynamicConfig,
  entry: app_config.AppConfigEntry,
) -> Result(DynamicConfig, String) {
  use value <- result.try(
    json.parse(entry.value, decode.int)
    |> result.map_error(fn(err) {
      "Failed to decode cleanup app_config for "
      <> entry.key
      <> ": "
      <> string.inspect(err)
    }),
  )

  let cleanup = case entry.key {
    "api_log_retention_days" ->
      CleanupConfig(..config.cleanup, api_log_retention_days: value)
    "page_log_retention_days" ->
      CleanupConfig(..config.cleanup, page_log_retention_days: value)
    "pageview_log_retention_days" ->
      CleanupConfig(..config.cleanup, pageview_log_retention_days: value)
    "run_log_retention_days" ->
      CleanupConfig(..config.cleanup, run_log_retention_days: value)
    "job_log_retention_days" ->
      CleanupConfig(..config.cleanup, job_log_retention_days: value)
    "jobs_retention_days" ->
      CleanupConfig(..config.cleanup, jobs_retention_days: value)
    "login_tokens_retention_days" ->
      CleanupConfig(..config.cleanup, login_tokens_retention_days: value)
    "user_actions_retention_days" ->
      CleanupConfig(..config.cleanup, user_actions_retention_days: value)
    _ -> config.cleanup
  }

  Ok(DynamicConfig(..config, cleanup: cleanup))
}

fn decode_docker_run_entry(
  config: DynamicConfig,
  entry: app_config.AppConfigEntry,
) -> Result(DynamicConfig, String) {
  use value <- result.try(
    json.parse(entry.value, decode.string)
    |> result.map_error(fn(err) {
      "Failed to decode docker_run app_config for "
      <> entry.key
      <> ": "
      <> string.inspect(err)
    }),
  )

  let docker_run =
    case entry.key, config.docker_run {
      "base_url", option.Some(docker_run) ->
        option.Some(DockerRunConfig(base_url: value, access_token: docker_run.access_token))
      "base_url", option.None ->
        option.Some(DockerRunConfig(base_url: value, access_token: ""))
      "access_token", option.Some(docker_run) ->
        option.Some(DockerRunConfig(base_url: docker_run.base_url, access_token: value))
      "access_token", option.None ->
        option.Some(DockerRunConfig(base_url: "", access_token: value))
      _, _ -> config.docker_run
    }

  Ok(DynamicConfig(..config, docker_run: docker_run))
}

fn decode_rate_limit_policy_entry(
  config: DynamicConfig,
  entry: app_config.AppConfigEntry,
) -> Result(DynamicConfig, String) {
  use action <- result.try(case api_action.from_string(entry.key) {
    option.Some(action) -> Ok(action)
    option.None -> Error("Invalid rate limit action in app_config key: " <> entry.key)
  })
  use policy <- result.try(
    json.parse(entry.value, rate_limit_policy_decoder())
    |> result.map_error(fn(err) {
      "Failed to decode rate_limit app_config for "
      <> entry.key
      <> ": "
      <> string.inspect(err)
    }),
  )
  Ok(DynamicConfig(
    ..config,
    rate_limit_policies: dict.insert(config.rate_limit_policies, action, policy),
  ))
}

fn rate_limit_policy_decoder() -> decode.Decoder(RateLimitPolicy) {
  use rules <- decode.field("rules", decode.list(rate_limit_rule_decoder()))
  decode.success(RateLimitPolicy(rules: rules))
}

fn encode_rate_limit_rule(rule: RateLimitRule) -> json.Json {
  json.object([
    #("match", encode_rate_limit_match(rule.match)),
    #("limits", json.array(rule.limits, encode_rate_limit)),
  ])
}

fn encode_rate_limit_match(rule_match: RateLimitMatch) -> json.Json {
  case rule_match {
    AnonymousMatch ->
      json.object([#("actor", json.string("anonymous"))])
    AuthenticatedMatch(account_tiers: account_tiers) ->
      json.object([
        #("actor", json.string("authenticated")),
        #(
          "account_tiers",
          json.nullable(account_tiers, fn(account_tiers) {
            json.array(account_tiers, fn(account_tier) {
              json.string(account_model.account_tier_to_string(account_tier))
            })
          }),
        ),
      ])
  }
}

fn encode_rate_limit(rate_limit_value: rate_limit.RateLimit) -> json.Json {
  json.object([
    #("unit", json.string(rate_limit.unit_to_string(rate_limit_value.unit))),
    #("max_requests", json.int(rate_limit_value.max_requests)),
  ])
}

fn rate_limit_rule_decoder() -> decode.Decoder(RateLimitRule) {
  use match <- decode.field("match", rate_limit_match_decoder())
  use limits <- decode.field("limits", decode.list(rate_limit_decoder()))
  decode.success(RateLimitRule(match:, limits:))
}

fn rate_limit_match_decoder() -> decode.Decoder(RateLimitMatch) {
  use actor <- decode.field("actor", decode.string)
  case actor {
    "anonymous" -> decode.success(AnonymousMatch)
    "authenticated" -> {
      use account_tiers <- decode.field(
        "account_tiers",
        decode.optional(decode.list(account_tier_decoder())),
      )
      decode.success(AuthenticatedMatch(account_tiers: account_tiers))
    }
    _ -> decode.failure(AnonymousMatch, "RateLimitMatch")
  }
}

fn rate_limit_decoder() -> decode.Decoder(rate_limit.RateLimit) {
  use unit <- decode.field("unit", time_unit_decoder())
  use max_requests <- decode.field("max_requests", decode.int)
  decode.success(rate_limit.RateLimit(unit:, max_requests:))
}

fn time_unit_decoder() -> decode.Decoder(rate_limit.TimeUnit) {
  use value <- decode.then(decode.string)
  case rate_limit.unit_from_string(value) {
    option.Some(unit) -> decode.success(unit)
    option.None -> decode.failure(rate_limit.Minute, "TimeUnit")
  }
}

fn account_tier_decoder() -> decode.Decoder(account_model.AccountTier) {
  use value <- decode.then(decode.string)
  case account_model.account_tier_from_string(value) {
    option.Some(tier) -> decode.success(tier)
    option.None -> decode.failure(account_model.FreeTier, "AccountTier")
  }
}

fn rule_match_priority(
  rule_match: RateLimitMatch,
  actor: RateLimitActor,
) -> option.Option(Int) {
  case rule_match, actor {
    AnonymousMatch, AnonymousActor -> option.Some(1)
    AuthenticatedMatch(account_tiers: option.None), AuthenticatedActor(_) ->
      option.Some(2)
    AuthenticatedMatch(account_tiers: option.Some(account_tiers)), AuthenticatedActor(
      actor_tier,
    ) ->
      case list.contains(account_tiers, actor_tier) {
        True -> option.Some(3)
        False -> option.None
      }
    _, _ -> option.None
  }
}
