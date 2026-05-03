import glot_backend/dynamic_config
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_backend/effect/app_config/app_config_algebra

pub fn get_dynamic_config_result() -> program_types.Program(
  Result(dynamic_config.DynamicConfig, error.DbQueryError),
) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.GetDynamicConfig(next: program_types.Pure),
    ),
  )
}

pub fn get_dynamic_config() -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.GetDynamicConfig(next: fn(result) {
        case result {
          Ok(config) -> program_types.Pure(config)
          Error(err) -> program_types.Fail(error.QueryError(err))
        }
      }),
    ),
  )
}
