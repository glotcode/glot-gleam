import gleam/option
import glot_backend/app_config/ports/cache.{type Cache}
import glot_backend/run_code/ports/language_version_cache.{
  type LanguageVersionCache,
}

pub type CachePorts {
  CachePorts(
    app_config_cache: option.Option(Cache),
    language_version_cache: option.Option(LanguageVersionCache),
  )
}

pub fn without_caches() -> CachePorts {
  CachePorts(app_config_cache: option.None, language_version_cache: option.None)
}
