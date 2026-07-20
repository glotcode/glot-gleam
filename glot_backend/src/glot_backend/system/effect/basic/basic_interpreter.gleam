import gleam/option
import gleam/result
import glot_backend/app_config/decoder/config as config_decoder
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/system/effect/basic/basic_algebra
import glot_backend/system/effect/database_ports
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/log
import glot_backend/system/effect/program_state
import glot_backend/system/effect/program_types
import glot_backend/system/effect/runtime
import glot_backend/system/request/context
import glot_backend/system/runtime/erlang

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
      let value = runtime.services.system.basic.new_token(length, alphabet)
      continue(
        next(value),
        program_state.add_effect_measurement(
          state,
          effect_trace.BasicEffectName(basic_algebra.NewTokenEffectName),
          effect_trace.RuntimeEffect,
          started_at,
        ),
      )
    }
    basic_algebra.SystemTime(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = runtime.services.system.basic.system_time()
      continue(
        next(value),
        program_state.add_effect_measurement(
          state,
          effect_trace.BasicEffectName(basic_algebra.SystemTimeEffectName),
          effect_trace.RuntimeEffect,
          started_at,
        ),
      )
    }
    basic_algebra.UuidV7(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = runtime.services.system.basic.uuid_v7(ctx.timestamp)
      continue(
        next(value),
        program_state.add_effect_measurement(
          state,
          effect_trace.BasicEffectName(basic_algebra.UuidV7EffectName),
          effect_trace.RuntimeEffect,
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
              effect_trace.LogEffect,
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
              effect_trace.LogEffect,
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
                  effect_trace.LogEffect,
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
  let config_result = case runtime.services.caches.app_config_cache {
    option.Some(port) -> {
      let #(result, _) = port.lookup()
      result
    }
    option.None ->
      database_ports.app_config(runtime.services.database).list_entries()
      |> result.try(fn(entries) {
        config_decoder.from_entries(entries)
        |> result.map_error(db_error.DbQueryError)
      })
  }

  case config_result {
    Ok(config) -> dynamic_config.debug_config(config).enabled
    Error(_) -> False
  }
}
