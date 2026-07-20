import gleam/option.{type Option}
import gleam/result
import glot_backend/app_config/decoder/value
import glot_backend/app_config/model/entry.{type AppConfigEntry}
import glot_backend/run_code/model/config.{
  type DockerRunConfig, type LanguageVersionCacheWorkerConfig,
}

pub fn docker_run(
  current: Option(DockerRunConfig),
  default: DockerRunConfig,
  entry: AppConfigEntry,
) -> Result(Option(DockerRunConfig), String) {
  let base = option.unwrap(current, default)

  case entry.key {
    "base_url" -> {
      use decoded <- result.try(value.string("docker_run", entry))
      Ok(option.Some(config.DockerRunConfig(..base, base_url: decoded)))
    }
    "access_token" -> {
      use decoded <- result.try(value.string("docker_run", entry))
      Ok(option.Some(config.DockerRunConfig(..base, access_token: decoded)))
    }
    "default_timeout_ms" -> {
      use decoded <- result.try(value.int("docker_run", entry))
      Ok(option.Some(
        config.DockerRunConfig(..base, default_timeout_ms: decoded),
      ))
    }
    _ -> Ok(current)
  }
}

pub fn language_version_cache_worker(
  current: LanguageVersionCacheWorkerConfig,
  entry: AppConfigEntry,
) -> Result(LanguageVersionCacheWorkerConfig, String) {
  use decoded <- result.try(value.int("language_version_cache_worker", entry))

  case entry.key {
    "refresh_interval_ms" ->
      Ok(
        config.LanguageVersionCacheWorkerConfig(
          ..current,
          refresh_interval_ms: decoded,
        ),
      )
    "refresh_step_delay_ms" ->
      Ok(
        config.LanguageVersionCacheWorkerConfig(
          ..current,
          refresh_step_delay_ms: decoded,
        ),
      )
    "refresh_step_jitter_ms" ->
      Ok(
        config.LanguageVersionCacheWorkerConfig(
          ..current,
          refresh_step_jitter_ms: decoded,
        ),
      )
    "default_timeout_ms" ->
      Ok(
        config.LanguageVersionCacheWorkerConfig(
          ..current,
          default_timeout_ms: decoded,
        ),
      )
    _ -> Ok(current)
  }
}
