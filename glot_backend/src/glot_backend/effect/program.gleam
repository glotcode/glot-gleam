import gleam/dynamic
import gleam/dynamic/decode
import gleam/result
import glot_backend/effect/auth/auth
import glot_backend/effect/error
import glot_backend/effect/core/core
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/snippet/snippet
import glot_backend/effect/types

pub fn succeed(value: a) -> types.Program(a) {
  types.Pure(value)
}

pub fn fail(error: error.Error) -> types.Program(a) {
  types.Fail(error)
}

pub fn and_then(
  effect: types.Program(a),
  f: fn(a) -> types.Program(b),
) -> types.Program(b) {
  case effect {
    types.Pure(value) -> f(value)
    types.Fail(error) -> types.Fail(error)
    types.Impure(effect) ->
      types.Impure(map_effect(effect, fn(value) { and_then(value, f) }))
  }
}

pub fn map(effect: types.Program(a), f: fn(a) -> b) -> types.Program(b) {
  and_then(effect, fn(value) { succeed(f(value)) })
}

pub fn from_result(value: Result(a, error.Error)) -> types.Program(a) {
  case value {
    Ok(v) -> types.Pure(v)
    Error(err) -> types.Fail(err)
  }
}

pub fn decode_json(
  json_body: dynamic.Dynamic,
  decoder: decode.Decoder(a),
) -> types.Program(a) {
  decode.run(json_body, decoder)
  |> result.map_error(error.DecodeError)
  |> from_result
}

pub fn when(condition: Bool, if_true: types.Program(Nil)) -> types.Program(Nil) {
  case condition {
    True -> if_true
    False -> types.Pure(Nil)
  }
}

fn map_effect(effect: types.Effect(a), f: fn(a) -> b) -> types.Effect(b) {
  case effect {
    types.CoreEffect(effect) -> types.CoreEffect(core.map(effect, f))
    types.AuthEffect(effect) -> types.AuthEffect(auth.map(effect, f))
    types.SnippetEffect(effect) -> types.SnippetEffect(snippet.map(effect, f))
    types.DockerRunEffect(effect) ->
      types.DockerRunEffect(docker_run.map(effect, f))
    types.TransactionEffect(commands, next) ->
      types.TransactionEffect(commands, fn(value) { f(next(value)) })
  }
}
