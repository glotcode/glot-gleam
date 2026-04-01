import glot_backend/effect/core/core
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/effect/program_state
import glot_backend/erlang
import glot_backend/log

pub fn run(
  effect: core.CoreEffect(effect_model.Program(a)),
  handlers: handlers_types.Handlers,
  state: program_state.State,
  continue: fn(effect_model.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    core.NewToken(length, next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = handlers.core.new_token(length)
      continue(
        next(value),
        program_state.measure_effect(state, effect_model.NewTokenEffect, started_at),
      )
    }
    core.SystemTime(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = handlers.core.system_time()
      continue(
        next(value),
        program_state.measure_effect(
          state,
          effect_model.SystemTimeEffect,
          started_at,
        ),
      )
    }
    core.UuidV7(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = handlers.core.uuid_v7()
      continue(
        next(value),
        program_state.measure_effect(state, effect_model.UuidV7Effect, started_at),
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
        program_state.measure_effect(state, effect_model.LogEffect, started_at),
      )
    }
    core.AttemptSendEmail(message, next) -> {
      let started_at = erlang.perf_counter_ns()
      let send_result = handlers.core.send_email(message)
      continue(
        next(send_result),
        program_state.measure_effect(state, effect_model.SendEmailEffect, started_at),
      )
    }
    core.GetNextJob(now:, pending_status:, running_status:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.core.get_next_job(now, pending_status, running_status)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.measure_effect(
              state,
              effect_model.RunQueryEffect(
                effect_model.CoreQueryName(core.GetNextJobQuery),
              ),
              started_at,
            ),
          )
        Error(error) ->
          #(
            Error(error.QueryError(error)),
            program_state.measure_effect(
              state,
              effect_model.RunQueryEffect(
                effect_model.CoreQueryName(core.GetNextJobQuery),
              ),
              started_at,
            ),
          )
      }
    }
    core.CountUserActionsByIp(windows:, ip:, action:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.core.count_user_actions_by_ip(windows, ip, action)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.measure_effect(
              state,
              effect_model.RunQueryEffect(
                effect_model.CoreQueryName(core.CountUserActionsByIpQuery),
              ),
              started_at,
            ),
          )
        Error(error) ->
          #(
            Error(error.QueryError(error)),
            program_state.measure_effect(
              state,
              effect_model.RunQueryEffect(
                effect_model.CoreQueryName(core.CountUserActionsByIpQuery),
              ),
              started_at,
            ),
          )
      }
    }
    core.CountUserActionsByUser(windows:, user_id:, action:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.core.count_user_actions_by_user(windows, user_id, action)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.measure_effect(
              state,
              effect_model.RunQueryEffect(
                effect_model.CoreQueryName(core.CountUserActionsByUserQuery),
              ),
              started_at,
            ),
          )
        Error(error) ->
          #(
            Error(error.QueryError(error)),
            program_state.measure_effect(
              state,
              effect_model.RunQueryEffect(
                effect_model.CoreQueryName(core.CountUserActionsByUserQuery),
              ),
              started_at,
            ),
          )
      }
    }
    core.InsertJob(job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.core.insert_job(job)
      continue(
        next(result),
        program_state.measure_effect(
          state,
          effect_model.RunCommandEffect(
            effect_model.CoreCommandName(core.InsertJobCommand),
          ),
          started_at,
        ),
      )
    }
    core.InsertUserAction(
      id: id,
      request_id: request_id,
      action: action,
      ip: ip,
      user_id: user_id,
      created_at: created_at,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.core.insert_user_action(
          id,
          request_id,
          action,
          ip,
          user_id,
          created_at,
        )
      continue(
        next(result),
        program_state.measure_effect(
          state,
          effect_model.RunCommandEffect(
            effect_model.CoreCommandName(core.InsertUserActionCommand),
          ),
          started_at,
        ),
      )
    }
    core.MarkJobDone(id, completed_at, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.core.mark_job_done(id, completed_at)
      continue(
        next(result),
        program_state.measure_effect(
          state,
          effect_model.RunCommandEffect(
            effect_model.CoreCommandName(core.MarkJobDoneCommand),
          ),
          started_at,
        ),
      )
    }
    core.RescheduleJob(id, run_at, last_error, updated_at, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.core.reschedule_job(id, run_at, last_error, updated_at)
      continue(
        next(result),
        program_state.measure_effect(
          state,
          effect_model.RunCommandEffect(
            effect_model.CoreCommandName(core.RescheduleJobCommand),
          ),
          started_at,
        ),
      )
    }
  }
}
