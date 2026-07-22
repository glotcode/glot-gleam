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

pub fn new(
  app_config_cache: Cache,
  language_version_cache: LanguageVersionCache,
) -> CachePorts {
  CachePorts(
    app_config_cache: option.Some(app_config_cache),
    language_version_cache: option.Some(language_version_cache),
  )
}

pub fn without_caches() -> CachePorts {
  CachePorts(app_config_cache: option.None, language_version_cache: option.None)
}
