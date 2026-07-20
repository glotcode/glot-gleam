pub type DockerRunConfig {
  DockerRunConfig(
    base_url: String,
    access_token: String,
    default_timeout_ms: Int,
  )
}

pub type LanguageVersionCacheWorkerConfig {
  LanguageVersionCacheWorkerConfig(
    refresh_interval_ms: Int,
    refresh_step_delay_ms: Int,
    refresh_step_jitter_ms: Int,
    default_timeout_ms: Int,
  )
}
