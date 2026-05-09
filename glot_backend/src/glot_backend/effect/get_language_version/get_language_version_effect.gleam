import glot_backend/context
import glot_backend/effect/error
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/program_types
import glot_core/language.{type Language}
import glot_core/run

pub fn get_language_version(
  cfg: context.Config,
  language: Language,
) -> program_types.Program(run.RunResult) {
  program_types.Impure(
    program_types.GetLanguageVersionEffect(
      get_language_version_algebra.GetLanguageVersion(
        cfg,
        language,
        fn(run_result) {
          case run_result {
            Ok(value) -> program_types.Pure(value)
            Error(err) -> program_types.Fail(error.RunError(err))
          }
        },
      ),
    ),
  )
}
