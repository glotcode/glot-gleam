import gleam/option
import glot_backend/effect/effect_trace
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/worker/language_version_cache_worker

pub fn run(
  effect: get_language_version_algebra.GetLanguageVersionEffect(
    program_types.Program(a),
  ),
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) -> #(b, program_state.State),
) -> #(b, program_state.State) {
  case effect {
    get_language_version_algebra.GetLanguageVersion(cfg, language, next) -> {
      let started_at = erlang.perf_counter_ns()
      let run_result =
        case runtime.language_version_cache_subject {
          option.Some(subject) ->
            language_version_cache_worker.get_language_version(subject, language)
          option.None ->
            runtime.handlers.get_language_version.get_language_version(
              cfg,
              language,
            )
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
