import glot_backend/effect/app_config/app_config_algebra
import glot_backend/effect/analytics/analytics_algebra
import glot_backend/effect/admin_log/admin_log_algebra
import glot_backend/effect/api_log/api_log_algebra
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/email/email_algebra
import glot_backend/effect/error
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/job/job_algebra
import glot_backend/effect/job_log/job_log_algebra
import glot_backend/effect/page_log/page_log_algebra
import glot_backend/effect/pageview_log/pageview_log_algebra
import glot_backend/effect/periodic_job/periodic_job_algebra
import glot_backend/effect/run_log/run_log_algebra
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/effect/transaction/transaction_algebra
import glot_backend/effect/user_action/user_action_algebra

pub fn succeed(value: a) -> program_types.Program(a) {
  program_types.Pure(value)
}

pub fn fail(error: error.Error) -> program_types.Program(a) {
  program_types.Fail(error)
}

pub fn and_then(
  effect: program_types.Program(a),
  f: fn(a) -> program_types.Program(b),
) -> program_types.Program(b) {
  case effect {
    program_types.Pure(value) -> f(value)
    program_types.Fail(error) -> program_types.Fail(error)
    program_types.Impure(effect) ->
      program_types.Impure(map_effect(effect, fn(value) { and_then(value, f) }))
  }
}

pub fn map(
  effect: program_types.Program(a),
  f: fn(a) -> b,
) -> program_types.Program(b) {
  and_then(effect, fn(value) { succeed(f(value)) })
}

pub fn to_result(
  effect: program_types.Program(a),
) -> program_types.Program(Result(a, error.Error)) {
  case effect {
    program_types.Pure(value) -> succeed(Ok(value))
    program_types.Fail(err) -> succeed(Error(err))
    program_types.Impure(inner) ->
      program_types.Impure(map_effect(inner, to_result))
  }
}

pub fn from_result(value: Result(a, error.Error)) -> program_types.Program(a) {
  case value {
    Ok(v) -> program_types.Pure(v)
    Error(err) -> program_types.Fail(err)
  }
}

pub fn from_option(
  value: option.Option(a),
  err: error.Error,
) -> program_types.Program(a) {
  case value {
    option.Some(v) -> program_types.Pure(v)
    option.None -> program_types.Fail(err)
  }
}

pub fn require(
  value: program_types.Program(option.Option(a)),
  err: error.Error,
) -> program_types.Program(a) {
  and_then(value, fn(value) { from_option(value, err) })
}

pub fn parse_json(
  json_str: String,
  decoder: decode.Decoder(a),
) -> program_types.Program(a) {
  json.parse(json_str, decoder)
  |> result.map_error(error.JsonParseError)
  |> from_result
}

pub fn decode_dynamic(
  data: dynamic.Dynamic,
  decoder: decode.Decoder(a),
) -> program_types.Program(a) {
  decode.run(data, decoder)
  |> result.map_error(error.DecodeError)
  |> from_result
}

pub fn when(
  condition: Bool,
  if_true: program_types.Program(Nil),
) -> program_types.Program(Nil) {
  case condition {
    True -> if_true
    False -> program_types.Pure(Nil)
  }
}

fn map_effect(
  effect: program_types.Effect(a),
  f: fn(a) -> b,
) -> program_types.Effect(b) {
  case effect {
    program_types.AppConfigEffect(effect) ->
      program_types.AppConfigEffect(app_config_algebra.map(effect, f))
    program_types.BasicEffect(effect) ->
      program_types.BasicEffect(basic_algebra.map(effect, f))
    program_types.EmailEffect(effect) ->
      program_types.EmailEffect(email_algebra.map(effect, f))
    program_types.DockerRunEffect(effect) ->
      program_types.DockerRunEffect(docker_run_algebra.map(effect, f))
    program_types.GetLanguageVersionEffect(effect) ->
      program_types.GetLanguageVersionEffect(
        get_language_version_algebra.map(effect, f),
      )
    program_types.DbEffect(effect) ->
      program_types.DbEffect(map_db_effect(effect, f))
    program_types.TransactionEffect(effect) ->
      program_types.TransactionEffect(transaction_algebra.map(effect, f))
  }
}

fn map_db_effect(
  effect: program_types.DbEffect(a),
  f: fn(a) -> b,
) -> program_types.DbEffect(b) {
  case effect {
    program_types.AnalyticsEffect(effect) ->
      program_types.AnalyticsEffect(analytics_algebra.map(effect, f))
    program_types.AdminLogEffect(effect) ->
      program_types.AdminLogEffect(admin_log_algebra.map(effect, f))
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
