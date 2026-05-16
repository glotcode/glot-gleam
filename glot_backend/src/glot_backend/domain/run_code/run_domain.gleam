import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/docker_run/docker_run_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/run_log/run_log_effect
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/language
import glot_core/public_action
import glot_core/run
import glot_core/run_log_model

pub fn run(
  ctx: context.Context,
  request: run.RunRequest,
) -> program_types.Program(run.RunResult) {
  use maybe_session <- program.and_then(session_domain.get_session(ctx))
  let maybe_session_id = option.map(maybe_session, fn(s) { s.identity.id })
  let maybe_user_id = option.map(maybe_session, fn(s) { s.user.identity.id })
  let maybe_user = option.map(maybe_session, fn(session) { session.user })
  use language <- program.and_then(program.from_option(
    language.from_container_image(request.image),
    error.ValidationError("Unknown run language for image: " <> request.image),
  ))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.string("image", request.image),
        log.string("language", language.to_string(language)),
        log.optional_uuid("session_id", maybe_session_id),
        log.optional_uuid("user_id", maybe_user_id),
      ]),
    ),
  )

  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(public_action.RunAction),
    actor: api_action_policy_domain.actor_from_user(maybe_user),
  ))

  use run_result <- program.and_then(docker_run_effect.run_code(request))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.string(
          "run_outcome",
          run_log_model.run_outcome_to_string(run_outcome(run_result)),
        ),
        log.optional_int("run_duration_ns", run_duration_ns(run_result)),
        log.optional_string(
          "run_failure_message",
          run_failure_message(run_result),
        ),
      ]),
    ),
  )

  use run_log_id <- program.and_then(basic_effect.uuid_v7())
  let run_log =
    run_log_model.RunLog(
      id: run_log_id,
      request_id: ctx.request_id,
      created_at: ctx.timestamp,
      session_id: maybe_session_id,
      user_id: maybe_user_id,
      language: language,
      outcome: run_outcome(run_result),
      duration_ns: run_duration_ns(run_result),
      failure_message: run_failure_message(run_result),
    )

  use _ <- program.and_then(
    transaction_effect.run_all([
      user_action_effect.create_user_action_tx(user_action),
      run_log_effect.create_tx(run_log),
    ]),
  )

  program.succeed(run_result)
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(run.RunRequest) {
  program.decode_dynamic(data, run.run_request_decoder())
}

fn run_outcome(run_result: run.RunResult) -> run_log_model.RunOutcome {
  case run_result {
    Ok(_) -> run_log_model.RunSucceeded
    Error(_) -> run_log_model.RunFailed
  }
}

fn run_duration_ns(run_result: run.RunResult) -> option.Option(Int) {
  case run_result {
    Ok(data) -> option.Some(data.duration)
    Error(_) -> option.None
  }
}

fn run_failure_message(run_result: run.RunResult) -> option.Option(String) {
  case run_result {
    Ok(_) -> option.None
    Error(data) -> option.Some(data.message)
  }
}
