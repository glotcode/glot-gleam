import gleam/option.{type Option}
import gleam/result
import glot_backend/app_config/decoder/value
import glot_backend/app_config/model/entry.{type AppConfigEntry}
import glot_backend/email/model/config.{type CloudflareConfig, type EmailConfig}

pub fn cloudflare(
  current: Option(CloudflareConfig),
  entry: AppConfigEntry,
) -> Result(Option(CloudflareConfig), String) {
  use decoded <- result.try(value.string("cloudflare", entry))

  Ok(case entry.key, current {
    "account_id", option.Some(config) ->
      option.Some(config.CloudflareConfig(..config, account_id: decoded))
    "account_id", option.None ->
      option.Some(config.CloudflareConfig(account_id: decoded, api_token: ""))
    "api_token", option.Some(config) ->
      option.Some(config.CloudflareConfig(..config, api_token: decoded))
    "api_token", option.None ->
      option.Some(config.CloudflareConfig(account_id: "", api_token: decoded))
    _, _ -> current
  })
}

pub fn email(
  current: Option(EmailConfig),
  default: EmailConfig,
  entry: AppConfigEntry,
) -> Result(Option(EmailConfig), String) {
  let base = option.unwrap(current, default)

  case entry.key {
    "from_address" -> {
      use decoded <- result.try(value.string("email", entry))
      Ok(option.Some(config.EmailConfig(..base, from_address: decoded)))
    }
    "from_name" -> {
      use decoded <- result.try(value.optional_string("email", entry))
      Ok(option.Some(config.EmailConfig(..base, from_name: decoded)))
    }
    "contact_address" -> {
      use decoded <- result.try(value.optional_string("email", entry))
      Ok(option.Some(config.EmailConfig(..base, contact_address: decoded)))
    }
    "default_timeout_ms" -> {
      use decoded <- result.try(value.int("email", entry))
      Ok(option.Some(config.EmailConfig(..base, default_timeout_ms: decoded)))
    }
    _ -> Ok(current)
  }
}
