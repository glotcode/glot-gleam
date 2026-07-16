import gleam/option
import glot_backend/context
import glot_backend/effect/effect_trace
import glot_backend/effect/error/run_request_error
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/worker/language_version_cache_worker/worker as language_version_cache_worker
import glot_core/language
import glot_core/run
import wisp

pub fn run(
  effect: get_language_version_algebra.GetLanguageVersionEffect(
    program_types.Program(a),
  ),
  runtime: runtime.Runtime,
  ctx: context.Context,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(b, program_state.State),
) -> #(b, program_state.State) {
  case effect {
    get_language_version_algebra.GetLanguageVersion(
      docker_run_config,
      language,
      next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let run_result = case runtime.language_version_cache_subject {
        option.Some(subject) ->
          language_version_cache_worker.get_language_version(subject, language)
        option.None ->
          case docker_run_config {
            option.Some(docker_run) ->
              runtime.handlers.docker_run.run_code(
                docker_run,
                run_request(language),
                option.unwrap(
                  context.remaining_timeout_ms(ctx),
                  docker_run.default_timeout_ms,
                ),
              )
            option.None -> {
              wisp.log_error("Missing docker_run app_config")
              Error(run_request_error.ServerRunRequestError)
            }
          }
      }

      continue(
        next(run_result),
        program_state.add_effect_measurement(
          state,
          effect_trace.GetLanguageVersionEffectName(
            get_language_version_algebra.GetLanguageVersionEffectName,
          ),
          effect_trace.DockerRunEffectCategory,
          started_at,
        ),
      )
    }
  }
}

fn run_request(requested_language: language.Language) -> run.RunRequest {
  run.RunRequest(
    image: language.container_image(requested_language),
    payload: run.RunRequestPayload(
      run_instructions: language.version_run_instructions(requested_language),
      files: [],
      stdin: option.None,
    ),
  )
}
