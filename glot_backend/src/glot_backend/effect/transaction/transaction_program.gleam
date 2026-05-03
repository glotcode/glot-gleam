import glot_backend/effect/analytics/analytics_algebra
import glot_backend/effect/api_log/api_log_algebra
import gleam/list
import gleam/option
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/error
import glot_backend/effect/job/job_algebra
import glot_backend/effect/job_log/job_log_algebra
import glot_backend/effect/page_log/page_log_algebra
import glot_backend/effect/pageview_log/pageview_log_algebra
import glot_backend/effect/periodic_job/periodic_job_algebra
import glot_backend/effect/run_log/run_log_algebra
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/effect/user_action/user_action_algebra

pub fn succeed(value: a) -> program_types.TransactionProgram(a) {
  program_types.TxPure(value)
}

pub fn fail(error: error.Error) -> program_types.TransactionProgram(a) {
  program_types.TxFail(error)
}

pub fn and_then(
  program: program_types.TransactionProgram(a),
  f: fn(a) -> program_types.TransactionProgram(b),
) -> program_types.TransactionProgram(b) {
  case program {
    program_types.TxPure(value) -> f(value)
    program_types.TxFail(error) -> program_types.TxFail(error)
    program_types.TxImpure(effect) ->
      program_types.TxImpure(
        map_db_effect(effect, fn(value) { and_then(value, f) }),
      )
  }
}

pub fn map(
  program: program_types.TransactionProgram(a),
  f: fn(a) -> b,
) -> program_types.TransactionProgram(b) {
  and_then(program, fn(value) { succeed(f(value)) })
}

pub fn to_result(
  program: program_types.TransactionProgram(a),
) -> program_types.TransactionProgram(Result(a, error.Error)) {
  case program {
    program_types.TxPure(value) -> succeed(Ok(value))
    program_types.TxFail(err) -> succeed(Error(err))
    program_types.TxImpure(effect) ->
      program_types.TxImpure(map_db_effect(effect, to_result))
  }
}

pub fn from_result(
  value: Result(a, error.Error),
) -> program_types.TransactionProgram(a) {
  case value {
    Ok(v) -> program_types.TxPure(v)
    Error(err) -> program_types.TxFail(err)
  }
}

pub fn from_option(
  value: option.Option(a),
  err: error.Error,
) -> program_types.TransactionProgram(a) {
  case value {
    option.Some(v) -> program_types.TxPure(v)
    option.None -> program_types.TxFail(err)
  }
}

pub fn require(
  value: program_types.TransactionProgram(option.Option(a)),
  err: error.Error,
) -> program_types.TransactionProgram(a) {
  and_then(value, fn(inner) { from_option(inner, err) })
}

pub fn sequence(
  programs: List(program_types.TransactionProgram(Nil)),
) -> program_types.TransactionProgram(Nil) {
  list.fold(programs, succeed(Nil), fn(acc, p) { and_then(acc, fn(_) { p }) })
}

fn map_db_effect(
  effect: program_types.DbEffect(a),
  f: fn(a) -> b,
) -> program_types.DbEffect(b) {
  case effect {
    program_types.AnalyticsEffect(effect) ->
      program_types.AnalyticsEffect(analytics_algebra.map(effect, f))
    program_types.ApiLogEffect(effect) ->
      program_types.ApiLogEffect(api_log_algebra.map(effect, f))
    program_types.AuthEffect(effect) ->
      program_types.AuthEffect(auth_algebra.map(effect, f))
    program_types.JobEffect(effect) ->
      program_types.JobEffect(job_algebra.map(effect, f))
    program_types.JobLogEffect(effect) ->
      program_types.JobLogEffect(job_log_algebra.map(effect, f))
    program_types.PageLogEffect(effect) ->
      program_types.PageLogEffect(page_log_algebra.map(effect, f))
    program_types.PageviewLogEffect(effect) ->
      program_types.PageviewLogEffect(pageview_log_algebra.map(effect, f))
    program_types.PeriodicJobEffect(effect) ->
      program_types.PeriodicJobEffect(periodic_job_algebra.map(effect, f))
    program_types.RunLogEffect(effect) ->
      program_types.RunLogEffect(run_log_algebra.map(effect, f))
    program_types.SnippetEffect(effect) ->
      program_types.SnippetEffect(snippet_algebra.map(effect, f))
    program_types.UserActionEffect(effect) ->
      program_types.UserActionEffect(user_action_algebra.map(effect, f))
  }
}
