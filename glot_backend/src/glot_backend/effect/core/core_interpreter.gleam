import glot_backend/effect/core/core
import glot_backend/effect/error
import glot_backend/effect/runtime_types
import glot_backend/effect/types
import glot_backend/erlang
import glot_backend/log

pub fn run(
  effect: core.CoreEffect(types.Program(a)),
  handlers: runtime_types.Handlers,
  state: types.State,
  continue: fn(types.Program(a), types.State) -> #(Result(a, error.Error), types.State),
  measure: fn(types.State, types.EffectName, Int) -> types.State,
) -> #(Result(a, error.Error), types.State) {
  case effect {
    core.NewToken(length, next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = handlers.new_token(length)
      continue(next(value), measure(state, types.NewTokenEffect, started_at))
    }
    core.SystemTime(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = handlers.system_time()
      continue(next(value), measure(state, types.SystemTimeEffect, started_at))
    }
    core.UuidV7(next) -> {
      let started_at = erlang.perf_counter_ns()
      let value = handlers.uuid_v7()
      continue(next(value), measure(state, types.UuidV7Effect, started_at))
    }
    core.Log(level, fields, next) -> {
      let started_at = erlang.perf_counter_ns()
      let state = case level {
        log.Info -> types.add_info_fields(state, fields)
        log.Warn -> types.add_warning_fields(state, fields)
      }
      continue(next, measure(state, types.LogEffect, started_at))
    }
    core.AttemptSendEmail(message, next) -> {
      let started_at = erlang.perf_counter_ns()
      let send_result = handlers.send_email(message)
      continue(next(send_result), measure(state, types.SendEmailEffect, started_at))
    }
    core.GetNextJob(now:, pending_status:, running_status:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.get_next_job(now, pending_status, running_status)
      case result {
        Ok(value) ->
          continue(
            next(value),
            measure(
              state,
              types.RunQueryEffect(types.CoreQueryName(core.GetNextJobQuery)),
              started_at,
            ),
          )
        Error(error) ->
          #(
            Error(error.QueryError(error)),
            measure(
              state,
              types.RunQueryEffect(types.CoreQueryName(core.GetNextJobQuery)),
              started_at,
            ),
          )
      }
    }
    core.CountUserActionsByIp(windows:, ip:, action:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.count_user_actions_by_ip(windows, ip, action)
      case result {
        Ok(value) ->
          continue(
            next(value),
            measure(
              state,
              types.RunQueryEffect(
                types.CoreQueryName(core.CountUserActionsByIpQuery),
              ),
              started_at,
            ),
          )
        Error(error) ->
          #(
            Error(error.QueryError(error)),
            measure(
              state,
              types.RunQueryEffect(
                types.CoreQueryName(core.CountUserActionsByIpQuery),
              ),
              started_at,
            ),
          )
      }
    }
    core.CountUserActionsByUser(windows:, user_id:, action:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.count_user_actions_by_user(windows, user_id, action)
      case result {
        Ok(value) ->
          continue(
            next(value),
            measure(
              state,
              types.RunQueryEffect(
                types.CoreQueryName(core.CountUserActionsByUserQuery),
              ),
              started_at,
            ),
          )
        Error(error) ->
          #(
            Error(error.QueryError(error)),
            measure(
              state,
              types.RunQueryEffect(
                types.CoreQueryName(core.CountUserActionsByUserQuery),
              ),
              started_at,
            ),
          )
      }
    }
    core.InsertJob(job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.insert_job(job)
      continue(
        next(result),
        measure(
          state,
          types.RunCommandEffect(
            types.CoreCommandName(core.InsertJobCommand),
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
        handlers.insert_user_action(
          id,
          request_id,
          action,
          ip,
          user_id,
          created_at,
        )
      continue(
        next(result),
        measure(
          state,
          types.RunCommandEffect(
            types.CoreCommandName(core.InsertUserActionCommand),
          ),
          started_at,
        ),
      )
    }
    core.MarkJobDone(id, completed_at, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.mark_job_done(id, completed_at)
      continue(
        next(result),
        measure(
          state,
          types.RunCommandEffect(
            types.CoreCommandName(core.MarkJobDoneCommand),
          ),
          started_at,
        ),
      )
    }
    core.RescheduleJob(id, run_at, last_error, updated_at, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.reschedule_job(id, run_at, last_error, updated_at)
      continue(
        next(result),
        measure(
          state,
          types.RunCommandEffect(
            types.CoreCommandName(core.RescheduleJobCommand),
          ),
          started_at,
        ),
      )
    }
  }
}
