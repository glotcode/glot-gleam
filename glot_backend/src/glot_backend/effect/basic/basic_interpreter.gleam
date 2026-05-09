import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/log
import glot_backend/worker/app_config_cache_worker

pub fn run(
  effect: basic_algebra.BasicEffect(program_types.Program(a)),
  ctx: context.Context,
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    basic_algebra.NewToken(length, alphabet, next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = runtime.handlers.basic.new_token(length, alphabet)
      continue(
        next(value),
        program_state.add_effect_measurement(
          state,
          effect_trace.BasicEffectName(basic_algebra.NewTokenEffectName),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
    basic_algebra.SystemTime(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = runtime.handlers.basic.system_time()
      continue(
        next(value),
        program_state.add_effect_measurement(
          state,
          effect_trace.BasicEffectName(basic_algebra.SystemTimeEffectName),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
    basic_algebra.UuidV7(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = runtime.handlers.basic.uuid_v7(ctx.timestamp)
      continue(
        next(value),
        program_state.add_effect_measurement(
          state,
          effect_trace.BasicEffectName(basic_algebra.UuidV7EffectName),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
    basic_algebra.Log(level, fields, next) -> {
      case level {
        log.Info -> {
          let started_at = erlang.perf_counter_ns()
          let state = program_state.add_info_fields(state, fields)
          continue(
            next,
            program_state.add_effect_measurement(
              state,
              effect_trace.BasicEffectName(basic_algebra.LogEffectName(level)),
              effect_trace.LogEffectCategory,
              started_at,
            ),
          )
        }
        log.Warn -> {
          let started_at = erlang.perf_counter_ns()
          let state = program_state.add_warning_fields(state, fields)
          continue(
            next,
            program_state.add_effect_measurement(
              state,
              effect_trace.BasicEffectName(basic_algebra.LogEffectName(level)),
              effect_trace.LogEffectCategory,
              started_at,
            ),
          )
        }
        log.Debug ->
          case debug_enabled(runtime) {
            True -> {
              let started_at = erlang.perf_counter_ns()
              let state = program_state.add_debug_fields(state, fields)
              continue(
                next,
                program_state.add_effect_measurement(
                  state,
                  effect_trace.BasicEffectName(basic_algebra.LogEffectName(
                    level,
                  )),
                  effect_trace.LogEffectCategory,
                  started_at,
                ),
              )
            }
            False -> continue(next, state)
          }
      }
    }
  }
}

fn debug_enabled(runtime: runtime.Runtime) -> Bool {
  let config_result = case runtime.app_config_cache_subject {
    option.Some(subject) -> app_config_cache_worker.get_config(subject)
    option.None ->
      runtime.handlers.app_config.list_entries()
      |> result.try(fn(entries) {
        dynamic_config.from_entries(entries)
        |> result.map_error(error.DbQueryError)
      })
  }

  case config_result {
    Ok(config) -> dynamic_config.debug_config(config).enabled
    Error(_) -> False
  }
}
