import glot_backend/dynamic_config
import glot_backend/effect/error

pub type AppConfigEffect(next) {
  GetDynamicConfig(
    next: fn(Result(dynamic_config.DynamicConfig, error.DbQueryError)) -> next,
  )
}

pub fn map(effect: AppConfigEffect(a), f: fn(a) -> b) -> AppConfigEffect(b) {
  case effect {
    GetDynamicConfig(next:) ->
      GetDynamicConfig(next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetDynamicConfigEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetDynamicConfigEffectName -> "get_dynamic_config"
  }
}
