import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/effect_trace
import glot_backend/effect/email/email_algebra
import glot_backend/effect/error
import glot_backend/effect/error/db_error
import glot_backend/effect/error/resource_error
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/worker/app_config_cache_worker
import wisp

pub fn run(
  effect: email_algebra.EmailEffect(program_types.Program(a)),
  ctx: context.Context,
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    email_algebra.SendEmail(message, next) -> {
      let started_at = erlang.perf_counter_ns()
      let send_result =
        load_config(runtime)
        |> result.try(fn(config) {
          let email_config = dynamic_config.email_config(config)
          case dynamic_config.cloudflare_config(config) {
            option.Some(cloudflare) ->
              runtime.handlers.email.send_email(
                cloudflare,
                message,
                option.unwrap(
                  context.remaining_timeout_ms(ctx),
                  email_config.default_timeout_ms,
                ),
              )
            option.None -> {
              wisp.log_error("Missing cloudflare app_config for email sending")
              Error(error.resource(resource_error.CloudflareConfigNotFound))
            }
          }
        })
      continue(
        next(send_result),
        program_state.add_effect_measurement(
          state,
          effect_trace.EmailEffectName(email_algebra.SendEmailEffectName),
          effect_trace.EmailEffectCategory,
          started_at,
        ),
      )
    }
  }
}

fn load_config(
  runtime: runtime.Runtime,
) -> Result(dynamic_config.DynamicConfig, error.Error) {
  case runtime.app_config_cache_subject {
    option.Some(subject) ->
      app_config_cache_worker.get_config(subject)
      |> result.map_error(error.database_query_error)
    option.None ->
      runtime.handlers.app_config.list_entries()
      |> result.map_error(error.database_query_error)
      |> result.try(fn(entries) {
        dynamic_config.from_entries(entries)
        |> result.map_error(fn(message) {
          error.database_query_error(db_error.DbQueryError(message))
        })
      })
  }
}
