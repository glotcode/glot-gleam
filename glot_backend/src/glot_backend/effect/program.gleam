import gleam/dynamic
import gleam/dynamic/decode
import gleam/result
import glot_backend/effect/auth/auth
import glot_backend/effect/core/core
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/job/job
import glot_backend/effect/snippet/snippet

pub fn succeed(value: a) -> effect_model.Program(a) {
  effect_model.Pure(value)
}

pub fn fail(error: error.Error) -> effect_model.Program(a) {
  effect_model.Fail(error)
}

pub fn and_then(
  effect: effect_model.Program(a),
  f: fn(a) -> effect_model.Program(b),
) -> effect_model.Program(b) {
  case effect {
    effect_model.Pure(value) -> f(value)
    effect_model.Fail(error) -> effect_model.Fail(error)
    effect_model.Impure(effect) ->
      effect_model.Impure(map_effect(effect, fn(value) { and_then(value, f) }))
  }
}

pub fn map(
  effect: effect_model.Program(a),
  f: fn(a) -> b,
) -> effect_model.Program(b) {
  and_then(effect, fn(value) { succeed(f(value)) })
}

pub fn from_result(value: Result(a, error.Error)) -> effect_model.Program(a) {
  case value {
    Ok(v) -> effect_model.Pure(v)
    Error(err) -> effect_model.Fail(err)
  }
}

pub fn decode_json(
  json_body: dynamic.Dynamic,
  decoder: decode.Decoder(a),
) -> effect_model.Program(a) {
  decode.run(json_body, decoder)
  |> result.map_error(error.DecodeError)
  |> from_result
}

pub fn when(
  condition: Bool,
  if_true: effect_model.Program(Nil),
) -> effect_model.Program(Nil) {
  case condition {
    True -> if_true
    False -> effect_model.Pure(Nil)
  }
}

fn map_effect(
  effect: effect_model.Effect(a),
  f: fn(a) -> b,
) -> effect_model.Effect(b) {
  case effect {
    effect_model.CoreEffect(effect) ->
      effect_model.CoreEffect(core.map(effect, f))
    effect_model.JobEffect(effect) ->
      effect_model.JobEffect(job.map(effect, f))
    effect_model.AuthEffect(effect) ->
      effect_model.AuthEffect(auth.map(effect, f))
    effect_model.SnippetEffect(effect) ->
      effect_model.SnippetEffect(snippet.map(effect, f))
    effect_model.DockerRunEffect(effect) ->
      effect_model.DockerRunEffect(docker_run.map(effect, f))
    effect_model.TransactionEffect(sub_effects, next) ->
      effect_model.TransactionEffect(sub_effects, fn(value) { f(next(value)) })
  }
}
