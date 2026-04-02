import glot_backend/context
import glot_backend/effect/core/core
import glot_backend/effect/program_types
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/erlang
import glot_backend/log

pub fn run(
  effect: core.CoreEffect(program_types.Program(a)),
  ctx: context.Context,
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    core.NewToken(length, next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = handlers.core.new_token(length)
      continue(
        next(value),
        program_state.add_effect_measurement(
          state,
          effect_trace.CoreEffectName(core.NewTokenEffectName),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
    core.SystemTime(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = handlers.core.system_time()
      continue(
        next(value),
        program_state.add_effect_measurement(
          state,
          effect_trace.CoreEffectName(core.SystemTimeEffectName),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
    core.UuidV7(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = handlers.core.uuid_v7(ctx.timestamp)
      continue(
        next(value),
        program_state.add_effect_measurement(
          state,
          effect_trace.CoreEffectName(core.UuidV7EffectName),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
    core.Log(level, fields, next) -> {
      let started_at = erlang.perf_counter_ns()
      let state = case level {
        log.Info -> program_state.add_info_fields(state, fields)
        log.Warn -> program_state.add_warning_fields(state, fields)
      }
      continue(
        next,
        program_state.add_effect_measurement(
          state,
          effect_trace.CoreEffectName(core.LogEffectName),
          effect_trace.LogEffectCategory,
          started_at,
        ),
      )
    }
    core.SendEmail(message, next) -> {
      let started_at = erlang.perf_counter_ns()
      let send_result = handlers.core.send_email(message)
      continue(
        next(send_result),
        program_state.add_effect_measurement(
          state,
          effect_trace.CoreEffectName(core.SendEmailEffectName),
          effect_trace.EmailEffectCategory,
          started_at,
        ),
      )
    }
  }
}
