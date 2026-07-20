import gleam/option.{type Option}

pub type CloudflareConfig {
  CloudflareConfig(account_id: String, api_token: String)
}

pub type EmailConfig {
  EmailConfig(
    from_address: String,
    from_name: Option(String),
    contact_address: Option(String),
    default_timeout_ms: Int,
  )
}
