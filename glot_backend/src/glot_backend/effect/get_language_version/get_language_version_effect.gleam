import gleam/option.{type Option}
import glot_backend/dynamic_config.{type DockerRunConfig}
import glot_backend/effect/error
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/program_types
import glot_core/language.{type Language}
import glot_core/run

pub fn get_language_version(
  docker_run_config: Option(DockerRunConfig),
  language: Language,
) -> program_types.Program(run.RunResult) {
  program_types.Impure(
    program_types.GetLanguageVersionEffect(
      get_language_version_algebra.GetLanguageVersion(
        docker_run_config,
        language,
        fn(run_result) {
          case run_result {
            Ok(value) -> program_types.Pure(value)
            Error(err) -> program_types.Fail(error.run_request_error(err))
          }
        },
      ),
    ),
  )
}
