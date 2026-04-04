import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import glot_backend/effect/auth/auth
import glot_backend/effect/basic/basic
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/email/email
import glot_backend/effect/error
import glot_backend/effect/job/job
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet
import glot_backend/effect/user_action/user_action

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
    program_types.BasicEffect(effect) ->
      program_types.BasicEffect(basic.map(effect, f))
    program_types.EmailEffect(effect) ->
      program_types.EmailEffect(email.map(effect, f))
    program_types.JobEffect(effect) ->
      program_types.JobEffect(job.map(effect, f))
    program_types.AuthEffect(effect) ->
      program_types.AuthEffect(auth.map(effect, f))
    program_types.SnippetEffect(effect) ->
      program_types.SnippetEffect(snippet.map(effect, f))
    program_types.DockerRunEffect(effect) ->
      program_types.DockerRunEffect(docker_run.map(effect, f))
    program_types.UserActionEffect(effect) ->
      program_types.UserActionEffect(user_action.map(effect, f))
    program_types.TransactionEffect(run) ->
      program_types.TransactionEffect(fn(db, ctx) {
        let #(value, state) = run(db, ctx)
        #(f(value), state)
      })
  }
}
