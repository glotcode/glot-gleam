import gleam/option
import glot_backend/run_code/effect/algebra
import glot_backend/run_code/model/config.{type DockerRunConfig}
import glot_backend/run_code/ports/language_version_cache.{
  type LanguageVersionCache,
}
import glot_backend/run_code/ports/runner.{type Runner}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error/run_request_error
import glot_backend/system/effect/program_state
import glot_backend/system/effect/program_types
import glot_backend/system/request/context
import glot_backend/system/runtime/erlang
import glot_core/language
import glot_core/run
import wisp

pub fn run(
  effect: algebra.RunCodeEffect(program_types.Program(a)),
  cache: option.Option(LanguageVersionCache),
  runner: Runner,
  ctx: context.Context,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(b, program_state.State),
) -> #(b, program_state.State) {
  let started_at = erlang.perf_counter_ns()
  let #(result, effect_name, category, next) = case effect {
    algebra.RunCode(config, request, next) -> #(
      run_with_runner(config, request, runner, ctx),
      algebra.RunCodeEffectName,
      effect_trace.DockerCallEffect,
      next,
    )
    algebra.GetLanguageVersion(config, requested_language, next) -> {
      let #(result, category) = case cache {
        option.Some(port) -> {
          let #(result, outcome) = port.lookup(requested_language)
          #(result, effect_trace.CacheReadEffect(outcome))
        }
        option.None -> #(
          run_with_runner(
            config,
            language_version_request(requested_language),
            runner,
            ctx,
          ),
          effect_trace.DockerCallEffect,
        )
      }
      #(result, algebra.GetLanguageVersionEffectName, category, next)
    }
  }

  continue(
    next(result),
    program_state.add_effect_measurement(
      state,
      effect_trace.RunCodeEffectName(effect_name),
      category,
      started_at,
    ),
  )
}

fn run_with_runner(
  config: option.Option(DockerRunConfig),
  request: run.RunRequest,
  runner: Runner,
  ctx: context.Context,
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  case config {
    option.Some(docker_run) ->
      runner.run(
        docker_run,
        request,
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

fn language_version_request(language: language.Language) -> run.RunRequest {
  run.RunRequest(
    image: language.container_image(language),
    payload: run.RunRequestPayload(
      run_instructions: language.version_run_instructions(language),
      files: [],
      stdin: option.None,
    ),
  )
}
