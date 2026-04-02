import gleam/json
import gleam/list
import glot_backend/effect/auth/auth
import glot_backend/effect/basic/basic
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/job/job
import glot_backend/effect/snippet/snippet
import glot_backend/effect/user_action/user_action

pub type EffectName {
  BasicEffectName(basic.EffectName)
  JobEffectName(job.EffectName)
  AuthEffectName(auth.EffectName)
  SnippetEffectName(snippet.EffectName)
  DockerRunEffectName(docker_run.EffectName)
  UserActionEffectName(user_action.EffectName)
  RunInTransactionEffectName(List(EffectMeasurement))
}

pub fn effect_name_to_string(effect_name: EffectName) -> String {
  case effect_name {
    BasicEffectName(name) -> basic.effect_name_to_string(name)
    JobEffectName(name) -> job.effect_name_to_string(name)
    AuthEffectName(name) -> auth.effect_name_to_string(name)
    SnippetEffectName(name) -> snippet.effect_name_to_string(name)
    DockerRunEffectName(name) -> docker_run.effect_name_to_string(name)
    UserActionEffectName(name) -> user_action.effect_name_to_string(name)
    RunInTransactionEffectName(_) -> "run"
  }
}

pub fn effect_name_to_family(effect_name: EffectName) -> String {
  case effect_name {
    BasicEffectName(_) -> "basic"
    JobEffectName(_) -> "job"
    AuthEffectName(_) -> "auth"
    SnippetEffectName(_) -> "snippet"
    DockerRunEffectName(_) -> "docker_run"
    UserActionEffectName(_) -> "user_action"
    RunInTransactionEffectName(_) -> "transaction"
  }
}

pub type EffectCategory {
  UtilEffectCategory
  LogEffectCategory
  DockerRunEffectCategory
  EmailEffectCategory
  DbReadEffectCategory
  DbWriteEffectCategory
}

pub fn effect_category_to_string(category: EffectCategory) -> String {
  case category {
    UtilEffectCategory -> "util"
    LogEffectCategory -> "log"
    DockerRunEffectCategory -> "docker_run"
    EmailEffectCategory -> "email"
    DbReadEffectCategory -> "db_read"
    DbWriteEffectCategory -> "db_write"
  }
}

pub type EffectMeasurement {
  EffectMeasurement(
    name: EffectName,
    category: EffectCategory,
    duration_ns: Int,
  )
}

pub fn encode_effect_measurements(effects: List(EffectMeasurement)) -> json.Json {
  json.object([
    #("effects", json.array(effects, encode_effect_measurement)),
    #(
      "summary",
      json.object([
        #("count", json.int(list.length(effects))),
        #(
          "duration_ns",
          json.int(
            list.fold(effects, 0, fn(acc, effect_measurement) {
              acc + effect_measurement.duration_ns
            }),
          ),
        ),
      ]),
    ),
  ])
}

pub fn encode_effect_measurement(
  effect_measurement: EffectMeasurement,
) -> json.Json {
  let effect_name = effect_measurement.name
  let duration_ns = effect_measurement.duration_ns
  let effect_category = effect_category_to_string(effect_measurement.category)
  case effect_name {
    RunInTransactionEffectName(sub_effects) ->
      json.object([
        #("category", json.string(effect_category)),
        #("family", json.string(effect_name_to_family(effect_name))),
        #("name", json.string(effect_name_to_string(effect_name))),
        #("effects", json.array(sub_effects, encode_effect_measurement)),
        #("duration_ns", json.int(duration_ns)),
      ])
    _ ->
      json.object([
        #("category", json.string(effect_category)),
        #("family", json.string(effect_name_to_family(effect_name))),
        #("name", json.string(effect_name_to_string(effect_name))),
        #("duration_ns", json.int(duration_ns)),
      ])
  }
}
