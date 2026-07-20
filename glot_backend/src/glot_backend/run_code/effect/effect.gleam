import gleam/option.{type Option}
import glot_backend/run_code/effect/algebra
import glot_backend/run_code/model/config.{type DockerRunConfig}
import glot_backend/system/effect/error
import glot_backend/system/effect/error/run_request_error.{type RunRequestError}
import glot_backend/system/effect/program_types
import glot_core/language.{type Language}
import glot_core/run

pub fn run_code(
  config: Option(DockerRunConfig),
  request: run.RunRequest,
) -> program_types.Program(run.RunResult) {
  program_types.Impure(
    program_types.RunCodeEffect(algebra.RunCode(config, request, from_result)),
  )
}

pub fn get_language_version(
  config: Option(DockerRunConfig),
  language: Language,
) -> program_types.Program(run.RunResult) {
  program_types.Impure(
    program_types.RunCodeEffect(algebra.GetLanguageVersion(
      config,
      language,
      from_result,
    )),
  )
}

fn from_result(
  result: Result(run.RunResult, RunRequestError),
) -> program_types.Program(run.RunResult) {
  case result {
    Ok(value) -> program_types.Pure(value)
    Error(err) -> program_types.Fail(error.run_request_error(err))
  }
}
